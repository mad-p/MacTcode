#!/bin/sh

for i in *[^w]@2x.tiff; do
  magick $i -alpha on -channel RGB -negate +channel ${i/@2x/w@2x}
  magick $i -resize 50% ${i/@2x/}
  magick ${i/@2x/w@2x} -resize 50% ${i/@2x/w}
done
