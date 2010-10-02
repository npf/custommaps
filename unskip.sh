#!/bin/bash

function tilecount {
	if which unzip >/dev/null 2>&1; then
		n=$(unzip -l "$1" | grep -e "\.\(jpg\|jpeg\|JPG\|JPEG\)$" | wc -l)
	elif which miniunzip >/dev/null 2>&1; then
		n=$(miniunzip -l "$1" | grep -e "\.\(jpg\|jpeg\|JPG\|JPEG\)$" | wc -l)
	fi
	echo $n
}

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
	t=$(tilecount "$f")
	printf "%4d | %s\n" $t "$f"
	T=$((T+t))
done
echo "=== Disabled ==="
for f in *.kmz.skip; do
	t=$(tilecount "$f")
	printf "%4d | %s\n" $t "$f"
done

echo "=== TOTAL: $T tiles ==="
if [ $T -gt 100 ]; then
	echo "==> WARNING: Your GPS allows 100 tiles MAX <=="
fi
