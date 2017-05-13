#!/bin/bash

ISTTY=0; if [ -t 1 ]; then ISTTY=1; fi
bold ()      { if [ $ISTTY -eq 1 ]; then tput bold;     fi; }
red ()       { if [ $ISTTY -eq 1 ]; then tput setaf 1;  fi; }
green ()     { if [ $ISTTY -eq 1 ]; then tput setaf 2;  fi; }
yellow ()    { if [ $ISTTY -eq 1 ]; then tput setaf 3;  fi; }
cyan ()      { if [ $ISTTY -eq 1 ]; then tput setaf 6;  fi; }
normalize () { if [ $ISTTY -eq 1 ]; then tput sgr0; fi; }

echo_bold ()      { echo -e "$(bold)$1$(normalize)"; }
echo_underline () { echo -e "\033[4m$1$(normalize)"; }
echo_color ()     { echo -e "$2$1$(normalize)"; }

output_br () { echo -e "-----------------------------"; }

function check_for_updates() {
    curl --silent https://raw.githubusercontent.com/stuntcoders/stunt_wprest_publishing_analyzer/master/wpanalyzer.sh > __wpanalyzer.temp

    if ! diff $0 "__wpanalyzer.temp" > /dev/null ; then
        echo "$(red)New version available$(normalize)"
        echo "Run \"$(green)wpanalyzer update$(normalize)\" to update to latest version"
    else
        echo "You have latest version of wpanalyzer"
    fi

    rm -r __wpanalyzer.temp
}

function self_update() {
    sudo rm -f wpanalyzer.sh /usr/local/bin/wpanalyzer
    wget https://raw.githubusercontent.com/stuntcoders/stunt_wprest_publishing_analyzer/master/wpanalyzer.sh
    sudo chmod +x ./wpanalyzer.sh
    sudo mv ./wpanalyzer.sh /usr/local/bin/wpanalyzer

    echo "$(green)wpanalyzer updated to latest version!$(normalize)"
    exit 0;
}

if [ "$1" = "update" ]; then
    self_update
    exit $?
fi

if [ "$1" = "version-check" ]; then
    check_for_updates
    exit $?
fi

if [ -z "$2" ]; then
    PROTOCOL="https"
else
    PROTOCOL=$2
fi

URL="https://$1/wp-json/wp/v2/posts?per_page=100"
URL2="https://$1/wp-json/wp/v2/posts?per_page=100&page=2"
STORAGE_FILE="$1.csv"
TEMP_FILE="$1.tmp"
CURRENT_Y_MONTH=$(date +"%Y-%m")

curl -s $URL | jsonv id,date > $STORAGE_FILE
curl -s $URL2 | jsonv id,date > $TEMP_FILE

awk -F "\"*T\"*" '{print $1}' $STORAGE_FILE > $TEMP_FILE
awk -F "\"*-\"*" '{print $1 "-" $2}' $STORAGE_FILE > $TEMP_FILE
mv $TEMP_FILE $STORAGE_FILE

sed 's/$/"/' $STORAGE_FILE > $TEMP_FILE
mv $TEMP_FILE $STORAGE_FILE

echo "ID,Date" | cat - $STORAGE_FILE > $TEMP_FILE
mv $TEMP_FILE $STORAGE_FILE

MINI=`csvstat -c 1 --min $STORAGE_FILE`
MAXI=`csvstat -c 1 --max $STORAGE_FILE`
COUN=`csvstat -c 1 --count $STORAGE_FILE | awk -F "\"* \"*" '{print $3}'`
STAT="LEVELED"
MEDIAN_EDIT_PER_ARTICLE=$((($MINI+$MAXI)/$COUN))


MINI_D=`csvstat -c 2 --min $STORAGE_FILE`
MAXI_D=`csvstat -c 2 --max $STORAGE_FILE`

csvcut -c Date $STORAGE_FILE > $TEMP_FILE
mv $TEMP_FILE $STORAGE_FILE

mv $STORAGE_FILE data.csv
csvsql --query "SELECT Date, COUNT(*) AS 'Posts count' FROM data GROUP BY Date" data.csv > $STORAGE_FILE && rm data.csv

MEDI=`csvstat -c 2 --mean $STORAGE_FILE | awk '{print int($1)}'`

# Add missing dates from 2010 on
for year in `seq 2010 $(date +'%Y')`; do
    for month in `seq 01 12`; do
        DATEZ="$year-$(printf "%02d" $month)"

        if [ "$DATEZ" \< "$CURRENT_Y_MONTH" ]; then
            if [ ! -z $(grep "$DATEZ" "$STORAGE_FILE") ]; then D=1; else echo "$DATEZ,0" >> $STORAGE_FILE; fi
        fi
    done
done

# Sort by dates
csvsort -c 1 --reverse $STORAGE_FILE > $TEMP_FILE
mv $TEMP_FILE $STORAGE_FILE

# Get stats for the last 3 and 6 months
head -n +7 $STORAGE_FILE > $TEMP_FILE
MEDI_6=`csvstat -c 2 --mean $TEMP_FILE | awk '{print int($1)}'`

head -n +4 $STORAGE_FILE > $TEMP_FILE
MEDI_3=`csvstat -c 2 --mean $TEMP_FILE | awk '{print int($1)}'`

rm $TEMP_FILE

output_br
echo "Median edits per article: $MEDIAN_EDIT_PER_ARTICLE"
echo "Total number of articles: $COUN"

output_br
if [ $(($MEDI_3+$MEDI_6)) -gt $(($MEDI*18/10)) ]; then
    echo "$(green)Stats are looking good!"
    STAT="GOOD"
elif [ $(($MEDI_3+$MEDI_6)) -lt $(($MEDI*18/10)) ]; then
    echo "$(red)Stats are looking bad. :("
    STAT="BAD"
else
    echo "$(yellow)Stats are pretty much leveled..."
fi

echo "Median articles per month when publishing: $MEDI"
echo "Median articles pr month in last 6 months: $MEDI_6"
echo "Median articles pr month in last 3 months: $MEDI_3"

if [ $MEDI -lt  3 ]; then
    STAT="LOW"
    echo "$(cyan)$(bold)Keep in mind that median number of articles is lower than 3."
fi

echo "$(normalize)"
output_br

if [ "$3" = "file" ]; then
    if [ ! -f wpanalyzer.csv ]; then
        echo "Domain,Median,Median 6 months,Median 3 months,Stat" > wpanalyzer.csv
    fi

    echo "$1,$MEDI,$MEDI_6,$MEDI_3,$STAT" >> wpanalyzer.csv
    rm $STORAGE_FILE
else
    tail -n +2 $STORAGE_FILE > $TEMP_FILE

    gnuplot << EOF
set terminal png
set output '$STORAGE_FILE.png'
set style data linespoints
set datafile separator ','
plot '$TEMP_FILE'
EOF
    rm $TEMP_FILE

    echo "CSV with number of articles published per month can be found in following file: $(green)$STORAGE_FILE$(normalize)"
    echo "Graph can be found here: $(green)$STORAGE_FILE.png$(normalize)"
    output_br
fi
