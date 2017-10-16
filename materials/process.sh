#!/bin/bash

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
FILE=$1
OUTFOLDER=$SCRIPTDIR/$2
TMP=$SCRIPTDIR/wip.md

pandoc $FILE --wrap=none --from=html-raw_html --to=markdown-raw_html-header_attributes+tex_math_dollars-definition_lists --atx-headers  -o $TMP

# Make sure block quotes have a space for empty lines
sed -i 's/^>$/> /g' $TMP

# Remove special classes on backticks and links
sed -i 's/{\.docutils \.literal}//g' $TMP
sed -i 's/{\.reference \.external}//g' $TMP
sed -i 's/{\.toc-backref}//g' $TMP

# Set the code block headers reasonably
sed -i 's/{\.doctest-block}/{\.python}/g' $TMP

sed -i 's/\s*{\.literal-block}\s*//g' $TMP

# Remove random &nbsp;
sed -i 's/\s*&nbsp;\s*//g' $TMP

# Remove the autogenerated table of contents and add a TOC widget
tail -n +$(grep -n -m 1 '^#' $TMP | sed  's/\([0-9]*\).*/\1/') $TMP > tmp.md
cp tmp.md $TMP
sed -i.old '1s;^;\n[[table-of-contents]]\n\n;' $TMP

# Remove links from headers
perl -i -pe 's/^(#+) \[([\d\.]+)[^\x00-\x7F]*(.+)\]\(.*\)/\1 \2 \3/g' $TMP

# Fix up code blocks
./deindent_codeblocks.py $TMP $TMP

# Fix up math (convert to dollar signs and un-escape stuff)
./fixup_math.py $TMP $TMP

# Make sure MathJax block maths are on their own lines
# perl -i -pe 'BEGIN {undef $/;} s/(\$\$[^\$]+\$\$)/\n\n$1\n\n/sgm' $TMP
perl -i -pe 'BEGIN {undef $/;} s/(\$\$[^\$]+\$\$)/\n\n$1\n\n/sgm' $TMP
# We might have over-spaced, some, so fix this
# Remove extra newlines at the end
perl -i -pe 'BEGIN {undef $/;} s/(\$\$[^\$]+\$\$)\n\n\n\n/$1\n\n/sgm' $TMP
perl -i -pe 'BEGIN {undef $/;} s/(\$\$[^\$]+\$\$)\n\n\n/$1\n\n/sgm' $TMP
# Remove extra newlines at the beginning
perl -i -pe 'BEGIN {undef $/;} s/\n\n\n\n(\$\$[^\$]+\$\$)/\n\n$1/sgm' $TMP
perl -i -pe 'BEGIN {undef $/;} s/\n\n\n(\$\$[^\$]+\$\$)/\n\n$1/sgm' $TMP

# Make sure bullet points don't start with extra whitespace
sed -i 's/^- \s*/- /g' $TMP

# Split into sub-sections
chapter=$(echo $FILE | sed -rn 's/[^[:digit:]]*([[:digit:]]+)[^[:digit:]]*/\1/p')
base=$(echo $TMP | cut -f 1 -d '.')
i="1"
cp $TMP ${base}.${i}.md;
number_re='^[0-9]+$'
while true; do
    offset=$(cat ${base}.${i}.md | grep "# $chapter.$[$i+1]" -m 1 -b | sed 's/:.*//')
    echo "offset: $offset"

    if ! [[ $offset =~ $number_re ]] ; then
        break
    fi

    echo "" > ${base}.$[$i+1].md
    echo "[[table-of-contents]]" >> ${base}.$[$i+1].md
    cat ${base}.${i}.md | tail -c +$offset >> ${base}.$[$i+1].md
    cat ${base}.${i}.md | head -c +$offset > tmp.md
    cp tmp.md ${base}.${i}.md

    title=$(cat ${base}.${i}.md | grep "# $chapter.$i" -m 1 | cut -c 3-)
    echo "title: $title"

    cp ${base}.${i}.md $OUTFOLDER/"$title.md"

    i=$[$i+1]
done

rm -f $base*.md
rm -f $TMP.old
rm -f tmp.md
