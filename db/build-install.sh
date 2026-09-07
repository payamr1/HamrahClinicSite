#!/bin/sh
# بازتولید db/install.sql از چهار فایل جداگانه
cd "$(dirname "$0")/.." || exit 1
perl db/seed/gen-pages.pl && perl db/seed/gen-content.pl
