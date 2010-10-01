#!/bin/bash
shopt -s nullglob
for f in *.kmz; do
	mv "$f" "$f.skip"
done
for f in "$@"; do
	if [ "${f##*.}" == "skip" ]; then
		ff=${f%.skip};
		if [ "${ff##*.}" == "kmz" ]; then
			mv "$f" "$ff"
		fi
	fi
done

echo "=== Enabled ==="
T=0
for f in *.kmz; do
	t=$(zipinfo -1 "$f" "*.jpg" "*.jpeg" "*.JPG" "*.JPEG" 2> /dev/null | wc -l)
	printf "%4d | %s\n" $t "$f"
	T=$((T+t))
done

echo "=== Disabled ==="
for f in *.kmz.skip; do
	t=$(zipinfo -1 "$f" "*.jpg" "*.jpeg" "*.JPG" "*.JPEG" 2> /dev/null | wc -l)
	printf "%4d | %s\n" $t "$f"
done

echo "=== TOTAL: $T tiles ==="
if [ $T -gt 100 ]; then
	echo "==> WARNING: Your GPS allows 100 tiles MAX <=="
fi
