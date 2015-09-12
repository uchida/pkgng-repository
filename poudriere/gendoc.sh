#!/bin/sh
cd $1
rm -f index.html error.html
sh -c '
  echo "<html><body><ul>";
  ls | while read f; do echo "<li><a href=\"$f\">$f</a></li>"; done;
  echo "</ul></body></html>"
'> index.html
echo '' > error.html
