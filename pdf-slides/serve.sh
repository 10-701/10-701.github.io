#!/bin/sh
# Serve this folder on your local network so other devices (e.g. an iPad) can open the app.
# Usage:  sh serve.sh [port] [max-age]     (defaults: port 8000, max-age 0; stop with Ctrl+C)
#
# Caching: files carry an ETag (a fingerprint of size + modification time), so browsers may keep them
# and later ask "has this changed?"; unchanged files get a short "304 Not Modified" reply.
#   max-age 0 (default): the browser checks on every load, so edits show up on the next reload.
#   max-age N: the browser reuses its copy for N seconds without asking, like a typical web host
#              (GitHub Pages uses 600). Edits then appear only after N seconds, or on a forced reload.
# Uses only tools that come with macOS (sh, perl, ipconfig, route, scutil).

PORT="${1:-8000}"
MAX_AGE="${2:-0}"
DIR="$(cd "$(dirname "$0")" && pwd)"

# The IP of the network interface that carries the default route (Wi-Fi or Ethernet),
# unless that is a VPN tunnel, which other devices on the network can't reach.
IFACE="$(route -n get default 2>/dev/null | awk '/interface:/ { print $2 }')"
case "$IFACE" in utun*|ipsec*|ppp*|"") IP="" ;; *) IP="$(ipconfig getifaddr "$IFACE" 2>/dev/null)" ;; esac
[ -z "$IP" ] && IP="$(ipconfig getifaddr en0 2>/dev/null)"
[ -z "$IP" ] && IP="$(ipconfig getifaddr en1 2>/dev/null)"
[ -z "$IP" ] && IP="$(hostname -I 2>/dev/null | awk '{ print $1 }')"   # non-Mac fallback
HOSTNAME_LOCAL="$(scutil --get LocalHostName 2>/dev/null)"

echo "Serving $DIR"
if [ -n "$IP" ]; then echo "http://$IP:$PORT/"; else echo "Could not find this computer's IP address." >&2; fi
[ -n "$HOSTNAME_LOCAL" ] && echo "http://$HOSTNAME_LOCAL.local:$PORT/"
echo "(this computer: http://localhost:$PORT/ — cache max-age $MAX_AGE s — press Ctrl+C to stop)" >&2

exec perl -e '
use strict; use warnings; use IO::Socket::INET; use POSIX qw(strftime setlocale LC_TIME); setlocale(LC_TIME, "C");   # English dates for HTTP headers
my ($port, $root, $maxage) = @ARGV;
my %type = (html => "text/html; charset=utf-8", js => "text/javascript", mjs => "text/javascript",
  json => "application/json", webmanifest => "application/manifest+json", wasm => "application/wasm",
  png => "image/png", svg => "image/svg+xml", css => "text/css", pdf => "application/pdf",
  ttf => "font/ttf", md => "text/plain; charset=utf-8");
my $server = IO::Socket::INET->new(LocalPort => $port, Listen => 64, ReuseAddr => 1, Proto => "tcp")
  or die "Could not listen on port $port ($!). Try another: sh serve.sh 8080\n";
$SIG{CHLD} = "IGNORE"; $SIG{PIPE} = "IGNORE";
while (my $c = $server->accept) {
  if (fork) { close $c; next; }                       # one child per connection
  alarm 30;                                            # drop idle connections
  my $req = <$c> // exit;
  my $inm = "";                                        # If-None-Match: the ETag the browser already has
  while (my $h = <$c>) { last if $h =~ /^\r?\n$/; $inm = $1 if $h =~ /^If-None-Match:\s*(.*?)\s*$/i }
  my ($method, $path) = $req =~ m{^(GET|HEAD) (\S+)};
  my ($code, $file) = (404, undef);
  if ($method) {
    $path =~ s/[?#].*//; $path =~ s/%([0-9A-Fa-f]{2})/chr hex $1/ge;
    $path .= "index.html" if $path =~ m{/$};
    $file = "$root$path";
    $code = ($path !~ m{(^|/)\.\.(/|$)} && -f $file && -r _) ? 200 : 404;
  } else { $code = 405 }
  my @st = $code == 200 ? stat($file) : ();
  my $etag = @st ? qq{"$st[7]-$st[9]"} : "";              # size-mtime: changes whenever the file does
  $code = 304 if $code == 200 && $inm eq $etag;
  print STDERR "$code $req";
  my $cache = "Cache-Control: " . ($maxage > 0 ? "max-age=$maxage" : "no-cache") . "\r\nETag: $etag\r\n" .
    "Last-Modified: " . (@st ? strftime("%a, %d %b %Y %H:%M:%S GMT", gmtime $st[9]) : "") . "\r\n";
  if ($code == 304) { print $c "HTTP/1.1 304 Not Modified\r\n${cache}Connection: close\r\n\r\n"; exit }
  if ($code != 200) {
    my $msg = $code == 404 ? "Not found" : "Method not allowed";
    print $c "HTTP/1.1 $code $msg\r\nContent-Type: text/plain\r\nContent-Length: " . length($msg) . "\r\nConnection: close\r\n\r\n$msg";
    exit;
  }
  my ($ext) = $file =~ /\.([^.\/]+)$/;
  open my $fh, "<:raw", $file or exit;
  print $c "HTTP/1.1 200 OK\r\nContent-Type: " . ($type{lc($ext // "")} // "application/octet-stream") .
    "\r\nContent-Length: " . (-s $fh) . "\r\n${cache}Connection: close\r\n\r\n";
  if ($method eq "GET") { local $/ = \65536; while (my $buf = <$fh>) { print $c $buf } }
  exit;
}' "$PORT" "$DIR" "$MAX_AGE"
