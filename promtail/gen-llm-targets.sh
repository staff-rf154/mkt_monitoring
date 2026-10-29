#!/bin/sh
while true; do
  out=/targets/llm.json
  tmp=$out.tmp
  printf '[' > "$tmp"
  first=1
  for d in /var/lib/docker/containers/*/; do
    id=$(basename "$d")
    name=$(grep -o '"Name":"/[^"]*"' "$d/config.v2.json" 2>/dev/null | head -1 | sed 's/"Name":"\///; s/"$//')
    case "$name" in
      llm-*)
        [ $first -eq 1 ] || printf ',' >> "$tmp"
        first=0
        printf '{"targets":["localhost"],"labels":{"job":"llm","container":"%s","__path__":"/var/lib/docker/containers/%s/%s-json.log"}}' "$name" "$id" "$id" >> "$tmp"
        ;;
    esac
  done
  printf ']' >> "$tmp"
  mv "$tmp" "$out"
  sleep 15
done
