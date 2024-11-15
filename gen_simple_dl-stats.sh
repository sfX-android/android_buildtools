#!/bin/bash
##################################################################################################
#
# Parse nginx log for downloading counts and generate a very simple report html
#
# example report: https://leech.binbash.rocks:8008/theme/stats_los.html
#
# Copyright 2019-2024: <steadfasterX |at| binbash #DOT# rocks>
##################################################################################################
VERSION="v0.6"

# a static date when you start using this script the first time
# it is just used for informational purpose to show in the title of the total count
FIRSTRUN="2019-01-01"

# start this tool like this to 
# DEBUG=1 gendllog_ng.sh
[ -z "$DEBUG" ] && DEBUG=0

# the base directory where the report file(s) should be placed
ROMDIR="/home/nightlies/roms/theme"

# the full path(s) to the webserver log(s)
# multiple log paths need to be separated by a space
WEBLOG="/var/log/nginx/leech/access.log"

# total counter for mAid stats
PERM_CNTMAID=/var/log/counter/maidstats.total

# report file names with their corresponding search pattern
# the format is as follows:
# STAT[N]=<full-path-to-local-report>:<search-pattern1|search-pattern2|search-patternN>
#  STAT[N] can be any number, just ensure you put new ones in "STATFILES=" variable
#  <full-path-to-local-report> is a local unique path accessible from the internet, becomes the actual report file
#  <filename1|filename2|filenameN> can be 1 or multiple regex pattern separated by a pipe
STATF1="$ROMDIR/stats_fwul.html:FWUL.*\.zip|FWUL.*\.iso|mAid.*iso"
STATF2="$ROMDIR/stats_los.html:lineage/.*/lineage.*\.zip"
STATF3="$ROMDIR/stats_aoscp.html:aoscp/.*/aoscp.*\.zip"
STATF4="$ROMDIR/stats_misc.html:misc/.*tar.gz|misc/.*\.apk"
STATF5="$ROMDIR/stats_stock.html:stock/.*/.*\.img|stock/.*/.*\.bin\s|stock/.*/.*\.7z|stock/.*/.*\.zip"
STATF6="$ROMDIR/stats_twrp.html:TWRP/.*/twrp.*\.img"
STATF7="$ROMDIR/stats_aokp.html:aokp/.*/aokp.*\.zip"
STATF8="$ROMDIR/stats_twrpfish.html:TWRP-in-FIsH.*tar\.gz"
STATF9="$ROMDIR/stats_rr.html:rr/.*/RR-.*\.zip"
STATF10="$ROMDIR/stats_unbrick.html:unbricking/.*/.*\.tot|unbricking/.*/.*\.msi|unbricking/.*/.*\.zip"
STATF11="$ROMDIR/stats_kernel.html:kernel/.*/.*\.img|kernel/.*/.*\.zip"
STATF12="$ROMDIR/stats_shrp.html:SHRP/.*/SHRP_v.*\.zip"
STATF13="$ROMDIR/stats_e-os.html:e-os/.*/e-.*\.zip"
STATF14="$ROMDIR/stats_axp.html:axp/.*/AXP.*\.zip"

# if you add additional STATF[N] statements above, add them here as well
# the parser will only handle the STATFILES var
STATFILES="$STATF1 $STATF2 $STATF3 $STATF4 $STATF5 $STATF6 $STATF7 $STATF8 $STATF9 $STATF10 $STATF11 $STATF12 $STATF13 $STATF14"

# besides the above defined search patterns these are excluded always
# separated by pipe, pattern can be a regex
EXCLUDE="/theme/|css|md5|sha256|sha512|\.prop"

################################################################################################################################

F_HELP(){
  cat <<_EOHELP

    $0 version - $VERSION
    a helper to generate VERY basic html reports

    it will:
     1. parse all logfiles defined in WEBLOG (currently set: $WEBLOG)
     2. search for given pattern(s)
     3. generate counts for found patterns
     4. stores the total result count in a persistent file
     5. generates a stats html report
     6. triggers a logrotate if all went fine

    Requirements:

      create: /etc/logrotate.d/weblog:

            $WEBLOG {
                    monthly
                    rotate 7
                    missingok
                    compress
            }

    Usage:

    $0 (without arguments)    regular usage. will run, parse, generate stats
    $0 fresh                  will skip any previous calculation results
    $0 help|-help|--help      this message

    Environment:

    export DEBUG=1            will print a lot of information and skips:
                              persistent file creation (step4), logrotate (step6)
                              step5 will create a stats file named <STATF[N]>.debug.html


_EOHELP
}

SKIPCALC=0

# parse args
case $1 in
    help|-help|--help) F_HELP; exit;;
    *clean|clean) SKIPCALC=1 ;;
esac

[ $DEBUG -eq 1 ] && SKIPCALC=1

# logging func
F_LOG(){
    MODE=$1
    MSG="$2"

    case $MODE in
        D) echo -e "$(date '+%F %T') - DEBUG - $MSG" ;;
        *) echo -e "$(date '+%F %T') - INFO - $MSG" ;;
    esac
}

# parse logs...
for statfile in $STATFILES;do
    if [ $DEBUG -eq 1 ];then
        SHTML="${statfile/:*}.debug.html"
        cp ${statfile/:*} $SHTML
    else
        SHTML="${statfile/:*}"
    fi
    SEARCHSTR="${statfile/*:}"
    TOTALCNT=${SHTML}.total
    PERM_CNT_FILE=${SHTML}.permtotal

    [ $DEBUG -eq 1 ] && F_LOG D "SHTML: $SHTML, TOTALCNT: $TOTALCNT, PERM_CNT_FILE: $PERM_CNT_FILE"

    cat > $SHTML <<EOHEAD
<html>
    <head>
        <meta charset="utf-8">
        <meta http-equiv="x-ua-compatible" content="IE=edge">
	<title>Download stats</title>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <link rel="stylesheet" href="../Nginx-Fancyindex-Theme/styles.css">
        <style type="text/css">
<!--
.tab { margin-left: 40px; }
.tabmore { margin-left: 80px; }
-->
</style>
</head>
<body>
<u><h2>Download Statistics (since last check)</h2></u>
(statistic last updated $(date '+%F %T'))<br/>
<br/>
EOHEAD

    # read in current stats
    if [ ! -f "$PERM_CNT_FILE" ] || [ $SKIPCALC -eq 1 ] ; then DLCNT=0; else eval $(cat $PERM_CNT_FILE);fi
    PASTCNT=$DLCNT

    for dl in $(zgrep -E -i "GET.*/.*($SEARCHSTR).* 200 " $WEBLOG | grep -E -v "($EXCLUDE)" |cut -d ' ' -f "7,9"|grep 200 |cut -d " " -f1);do
	echo "${dl##*/}<br/>" 
	DLCNT=$((DLCNT+1))
	echo $DLCNT > $TOTALCNT
    done | sort | uniq -c | sort -nr | sed 's#\([0-9]\) #\1 -- | -- #g'>> $SHTML

    [ $DEBUG -eq 1 ] && F_LOG D "grepped for $SEARCHSTR, got count of $(cat $TOTALCNT)"

    [ -f "$TOTALCNT" ] && echo "<br/><u><h2>Total Downloads (since: $FIRSTRUN)</h2></u><h2>$(cat $TOTALCNT)</h2>" >> $SHTML #&& echo -e "DLCNT=$(cat $TOTALCNT)\nUDATE=$(date +%F)" > ${PERM_CNT_FILE}.tmp

    #EVALCNT=$(source ${PERM_CNT_FILE}.tmp; echo $DLCNT)
    CURCNT=$(cat $TOTALCNT)
    #SUMCNT=$(($EVALCNT + $CURCNT))
    [ -z "$CURCNT" ] && CURCNT=0

    [ $DEBUG -eq 1 ] && F_LOG D "current count was $CURCNT (past count: $PASTCNT)"

    if [ "$CURCNT" -gt "$PASTCNT" ];then
        echo -e "DLCNT=$CURCNT\nUDATE=$(date +%F)" > ${PERM_CNT_FILE}
    else
        [ $DEBUG -eq 1 ] && F_LOG D "Not updating ${PERM_CNT_FILE} because: TOTALCNT ($TOTALCNT) is less then PASTCNT ($PASTCNT)"
    fi
    chmod +r ${PERM_CNT_FILE}

    # update mAid totals
    echo "$SHTML" | grep -E -qi "fwul|maid"
    if [ $? -eq 0 ];then
        [ "$DEBUG" -ne 1 ] && cp ${PERM_CNT_FILE} ${PERM_CNTMAID}
    fi

    echo "<br/><u><h2>Most recent downloads</h2></u><br/>" >> $SHTML
    for at in $(find $WEBLOG);do
        zgrep -E -i "GET.*/.*($SEARCHSTR).* 200 " $at | grep -E -v "($EXCLUDE)" |cut -d ' ' -f "4,7,9"|grep 200 | tr -d "[" |cut -d " " -f 1,2 && break
    done | sort -r | sed 's# /.*/# -- | -- #g' | sed 's#$#<br/>#g' >> $SHTML
    #done | sort -Mr | sort -ur --key=2 | sed 's# /.*/# -- | -- #g' | sed 's#$#<br/>#g' >> $SHTML

    if [ "$DEBUG" -eq 1 ];then
        for at in $(find $WEBLOG);do
            F_LOG D "$SEARCHSTR at $at excluding: $EXCLUDE"
        done
    fi

    echo -e "</html></body>" >> $SHTML

done

# FORCE logrotate run so we do not count everything again
[ $DEBUG -ne 1 ] && logrotate -f /etc/logrotate.d/weblog
