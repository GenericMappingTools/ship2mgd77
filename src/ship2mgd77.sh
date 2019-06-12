#!/bin/sh
# Author: Michael Hamilton
# June 2019
#
# Merge raw ship data and convert to standard exchange formats using mgd77convert
#
# Usage: ship2mgd77.sh <cruiseid>
# e.g., ship2mgd77.sh km1609
#
# To debug: Replace 1st line with #!/bin/sh -xv

if [ $# -eq 0 ]; then	# If no arg given we bail with this message
	echo "Usage: ship2mgd77.sh <cruiseid>" >& 2
	echo "	e.g., ship2mgd77.sh km1609" >& 2
	exit 1
fi

source s2m_params.sh

# Initialize nav filters for smoothing grav data
gnav_fw=$bgm3grav_fw
gnav_si=$bgm3grav_sample_interval

# Create outputdatapath directory if not already there
mkdir -p $outputdatapath

temp="/tmp/ship2mgd77.$$"
id=$1
orig=$1
outid=`echo $id | awk '{print tolower($1)}'`

procdir="$underwaypath"

# Additional code required for concatenating raw day files, not shown here

# Function to create an empty MGD77 header
emptyhdr () {
    echo '4        MGD77                                                                01'
    echo '                                                                              02'
    echo '                                                                              03'
    echo '                                                                              04'
    echo '                                                                              05'
    echo '                                                                              06'
    echo '                                                                              07'
    echo '                                                                              08'
    echo '                                                                              09'
    echo '                                                                              10'
    echo '                                                                              11'
    echo '                                                                              12'
    echo '                                                                              13'
    echo '                                                                              14'
    echo '                                                                              15'
    echo '                                                                              16'
    echo '                                                                              17'
    echo '                                                                              18'
    echo '                                                                              19'
    echo '                                                                              20'
    echo '                                                                              21'
    echo '                                                                              22'
    echo '                                                                              23'
    echo '                                                                              24'
}

# Determine if track crosses IDL or Prime Meridian (if it crosses both we cannot filter navigation since that introduces invalid positions with super high speeds)
sed -e 's/*gpo/ /g' -e 's/*gps/ /g'  $procdir/${id}_pos-mv  | gmt info -C > $temp.pos-mv.loninfo # lon limits in cols 17, 18
lonmin=`awk '{print $15}' $temp.pos-mv.loninfo`
lonmax=`awk '{print $16}' $temp.pos-mv.loninfo`
lontype=`gmt math -Q $lonmax 180 GT =` # 0 for +/-180, 1 for 0/360
wrap=`gmt math -Q $lonmax $lonmin SUB 358 GT =` # Passed over dateline or prime meridian (fails in unlikely case where track circles > 358 deg lon without crossing anti/meridian

# If +/-180 and crossed dateline, switch to 0-360, else if 0-360 and crossed prime meridian, switch to +/-180
if [ $lontype -eq 0 ]; then  
	if [ $wrap -eq 1 ]; then
		geofmt="--FORMAT_GEO_OUT=+D"
	else
		geofmt="--FORMAT_GEO_OUT=D"
	fi
elif [ $lontype -eq 1 ]; then
	if [ $wrap -e 1 ]; then
		geofmt="--FORMAT_GEO_OUT=D"
	else 
		geofmt="--FORMAT_GEO_OUT=+D"
	fi
fi
#echo "Lon type 0-360? $lontype Lon passes meridian discontinuity? $wrap Best internal format for avoiding bad nav interpolation? $geofmt"

# Remove common errors from nav file (duplicates, zeros, lat/lon out of range, speeds gt 15 knots)
# Note that most pos-mv files have 18 columns, but km0907, perhaps others, have just 9 columns
awk '{if ($1 != 0 && ($1 <= 2099 && $1 > 1940) && ($2 <= 366 && $2 >= 0) && ($3 <= 23 && $3 >= 0) && ($4 <= 59 && $4 >= 0) && ($5 <= 59 && $5 >= 0) && ($6 <= 999 && $6 >= 0) && $8 != 0 && $9 != 0 && (NF == 18 || NF == 9) && ($8 >= -90 && $8 <= 90) && ($9 >= -180 && $9 <= 360)) printf "%.4d-%.3dT%.2d:%.2d:%.2d.%.3d %3.9f %3.9f\n",$1,$2,$3,$4,$5,$6,$8,($9+360)%360}' $procdir/${id}_pos-mv | gmt convert $geofmt -fi0T -fo0t -fi8x -fo8x --FORMAT_DATE_IN=yyyy-jjj --FORMAT_FLOAT_OUT=%.12f | awk '{if ($1>prev) print prev=$1,$2,$3}' > $temp.ship2mgd77_pos-mv.tmp
    navlen=`wc -l $temp.ship2mgd77_pos-mv.tmp | awk '{print $1}'`
    $shipcode/lopassvel $navlen 20 < $temp.ship2mgd77_pos-mv.tmp > $temp.ship2mgd77_pos-mv.tmp2

if [ ! -s $procdir/${id}_pos-mv.bak ]; then
    \cp -f $procdir/${id}_pos-mv $procdir/${id}_pos-mv.bak
fi

# Smooth nav, or not 
startt=`head -n 1 $temp.ship2mgd77_pos-mv.tmp2 | awk '{printf "%d\n",$1}'`
endt=`tail -n 1 $temp.ship2mgd77_pos-mv.tmp2 | awk '{printf "%d\n",$1}'`
if [ $filternav -eq 1 ]; then
    gmt filter1d $temp.ship2mgd77_pos-mv.tmp2 -L$filternav_fw -T$startt/$endt/1 -Fg$filternav_fw --FORMAT_CLOCK_OUT=hh:mm:ss.xxx --FORMAT_FLOAT_OUT=%.12f -fi0t -fo0T --TIME_UNIT=s --FORMAT_DATE_OUT=yyyy:jjj | awk '{if ($4 > 0) print $0}' > $temp.pos-mv3
    gmt convert --FORMAT_GEO_OUT=D $temp.pos-mv3 --FORMAT_CLOCK_IN=hh:mm:ss.xxx --FORMAT_CLOCK_OUT=hh:mm:ss.xxx --FORMAT_FLOAT_OUT=%.12f -fi0T -fi2x -fo2x -fo0T --FORMAT_DATE_IN=yyyy:jjj --FORMAT_DATE_OUT=yyyy:jjj | sed -e 's/:/ /g' -e 's/T/ /g' | awk '{if ($1 != 0 && $6 != 0 && $7 != 0 && NF == 8 && ($6 >= -90 && $6 <= 90) && ($7 >= -180 && $7 <= 360)) printf "%.4d %.3d %.2d %.2d %06.3f *gps % 3.9f % 3.9f\n",$1,$2,$3,$4,$5,$6,$7}' | sed -e 's/./ /18' > $procdir/${id}_pos-mv_clean
else
    # Discard non-moving records
    awk '{if ($4 > 0) print $0}' $temp.ship2mgd77_pos-mv.tmp2 > $temp.pos-mv3
    \cp $procdir/${id}_pos-mv $procdir/${id}_pos-mv_clean
fi

# Pre-process geophysics
for field in dpth magy bgm3grav; do # dpth must be first (syntax: dpth magy bgm3grav)

    # Pre-process depth/mag/grav 
    # rdpth format: yyyy jjj hh mm ss msec dpth em122 em1002
    if [ -s $procdir/${id}_r$field ]; then
        if [ $field == "dpth" ]; then
            # Pick sonar column (em120/122 vs em1002/710
            ncols=`head $procdir/${id}_rdpth | awk '{print NF}' | gmt math STDIN SUM 10 DIV -Sl --FORMAT_FLOAT_OUT=%.0f =`
            if [ $ncols == 9 ]; then
                awk '{if (($1 <= 2099 && $1 > 1940) && ($2 <= 366 && $2 >= 0) && ($3 <= 23 && $3 >= 0) && ($4 <= 59 && $4 >= 0) && ($5 <= 59 && $5 >= 0) && ($6 <= 999 && $6 >= 0) && $8 < 12000 && $9 < 1000 && NF == 9) print $0}' $procdir/${id}_rdpth > $temp.mdpth
                # This chooses the deep water sonar whenever its column is deeper than 500 m, else it chooses the shallow water meter
                # Note that this can fail if both columns contain values
                awk '{if ($8 >= 500 && $9 == 0.0) print $1,$2,$3,$4,$5,$6,$8; else print $1,$2,$3,$4,$5,$6,$8}' $temp.mdpth > $temp.dpth
            else
                echo "Abort! Invalid column structure in $procdir/${id}_rdpth"
                exit
            fi

            # Get navigation at depth measurement times
	        # Pass depth records that temporally increase by at least a second
            awk '{printf "%.4d-%.3dT%.2d:%.2d:%.2d.%.3d % 8.4f %13.9f\n",$1,$2,$3,$4,$5,$6,$7,$2+($3+($4+$5/60)/60)/24}' $temp.dpth | gmt convert --FORMAT_CLOCK_IN=hh:mm:ss.xxx --FORMAT_DATE_IN=yyyy-jjj -fi0T -fo0t --FORMAT_FLOAT_OUT=%.12f | awk '{if ($1>prev+1) print prev=$1,$2,$3}' > $temp.tdj.1
            STIME=`gmt info $temp.tdj.1 -C --FORMAT_FLOAT_OUT=%.12f | awk '{print $1}'`
            ETIME=`gmt info $temp.tdj.1 -C --FORMAT_FLOAT_OUT=%.12f | awk '{print $2}'`
            awk '{printf "%04d-%03dT%02d:%02d:%02d.%03d %10.9f %10.9f \n",$1,$2,$3,$4,$5,$6,$9,$8}' $procdir/${id}_pos-mv_clean | gmt convert --FORMAT_CLOCK_IN=hh:mm:ss.xxx --FORMAT_DATE_IN=yyyy-jjj -fi0T -fo0t --FORMAT_FLOAT_OUT=%.12f | awk '{if ($1>prev && ($1>=st && $1<=en)) print prev=$1,$2,$3}' st=$STIME en=$ETIME > $temp.txy

            # Trim in case the data extend beyond the navigation
            gmt sample1d $temp.txy -T$temp.tdj.1 -Fl -N0 --FORMAT_GEO_OUT=D -f0t -f1x --FORMAT_FLOAT_OUT=%.12f | grep -v NaN > $temp.dnav.txy.1
            STIME=`gmt info $temp.dnav.txy.1 -C --FORMAT_FLOAT_OUT=%.12f | awk '{print $1}'`
            ETIME=`gmt info $temp.dnav.txy.1 -C --FORMAT_FLOAT_OUT=%.12f | awk '{print $2}'`
            awk '($1>=st)&&($1<=en) {print $0}' st=$STIME en=$ETIME  $temp.tdj.1 > $temp.tdj.d

            # Output cdpth
            # Output is yr, day, hr, min, sec, lat, lon, depth
            len1=`wc -l $temp.tdj.d | awk '{print $1}'`
            len2=`wc -l $temp.dnav.txy.1 | awk '{print $1}'`
            if [ $len1 != $len2 ]; then
                echo "Warning: nav and depth input files have different lengths" >& 2
                exit
            fi
            paste $temp.tdj.d $temp.dnav.txy.1 | awk '{if ($1 == $4) print $1,$5,$6,$2}' | gmt convert -fi0t -fo0T --FORMAT_DATE_OUT=yyyy:jjj --FORMAT_CLOCK_OUT=hh:mm:ss.xxx --FORMAT_FLOAT_OUT=%.12f | sed -e 's/:/ /g' -e 's/T/ /g' | awk '{printf "%.4d %.3d %.2d %.2d %06.3f % 3.9f % 3.9f % 7.3f \n",$1,$2,$3,$4,$5,$7,$6,$8}' | sed -e 's/./ /18' > $procdir/${id}_cdpth

            if [ ! -s $procdir/${id}_cdpth ] && [ $sample2depthtime -eq 1 ]; then
                echo "Failed to compute ${id}_cdpth - Unable to sample potential field data to depth times."
                sample2depthtime=0
            fi

        elif [ $field == "magy" ]; then
            # GENERIC CASE FOR G-882 MAG SURVEYS
	        # 1. Filter total field mag
            awk '{if (($1 <= 2099 && $1 > 1940) && ($2 <= 366 && $2 >= 0) && ($3 <= 23 && $3 >= 0) && ($4 <= 59 && $4 >= 0) && ($5 <= 59 && $5 >= 0) && ($6 <= 999 && $6 >= 0) && ($8 > 0 && $8 < 99999) && $9 > 0 && NF == 10) printf "%04d-%03dT%02d:%02d:%02d.%03d %06.3f % 5.2f % 5.2f\n",$1,$2,$3,$4,$5,$6,$8,$10+($10*'$m_scale'+'$m_bias'),$9}' $procdir/${id}_rmagy | gmt convert -fi0T -fo0t --FORMAT_DATE_IN=yyyy-jjj --FORMAT_FLOAT_OUT=%.3f | awk '{if ($1>prev) print prev=$1,$2,$3,$4}' | gmt convert -fi0t -fo0T --FORMAT_CLOCK_OUT=hh:mm:ss.xxx > $temp.tm
            startt=`head -n 1 $temp.tm | awk '{print $1}' | gmt convert -f0T --FORMAT_CLOCK_OUT=hh:mm`
            endt=`tail -n 1 $temp.tm | awk '{print $1}' | gmt convert -f0T --FORMAT_CLOCK_OUT=hh:mm`
            if [ $sample2depthtime -eq 1 ]; then
                mag_sample_interval=1
            fi	
            gmt filter1d $temp.tm -Fg$mag_fw -T$startt/$endt/$mag_sample_interval -L$mag_fw  --TIME_UNIT=s -f0T --FORMAT_CLOCK_OUT=hh:mm:ss.xxx --FORMAT_DATE_OUT=yyyy:jjj | sed -e '/>/d' -e 's/:/ /g' -e 's/T/ /g' | awk '{if (NF == 8 && ($6 >= 18000 && $6 <= 74000) && $8 > '$g882_min_sigstrength') printf "%.4d %.3d %.2d %.2d %06.3f % 9.3f % 5.2f \n",$1,$2,$3,$4,$5,$6,$7}' | sed -e 's/./ /18' > $procdir/${id}_rmagy_smooth

        elif [ $field == "bgm3grav" ]; then
            gnav_fw=$bgm3grav_fw
            gnav_si=$bgm3grav_sample_interval
	        if [ $sample2depthtime -eq 1 ]; then
                gnav_si=1
            fi
            awk '{if (($1 <= 2099 && $1 > 1940) && ($2 <= 366 && $2 >= 0) && ($3 <= 23 && $3 >= 0) && ($4 <= 59 && $4 >= 0) && ($5 <= 59 && $5 >= 0) && ($6 <= 999 && $6 >= 0) && ($8 > 0 && $8 < 99999) && ($8*'$bgm3scale'+'$bgm3bias' >= 900000 && $8*'$bgm3scale'+'$bgm3bias' <= 1100000) && NF == 10) printf "%.4d-%.3dT%.2d:%.2d:%.2d.%.3d % 9.3f\n",$1,$2,$3,$4,$5,$6,$8*'$bgm3scale'+'$bgm3bias'}' $procdir/${id}_rbgm3grav | gmt convert -fi0T -fo0t --FORMAT_DATE_IN=yyyy-jjj --FORMAT_FLOAT_OUT=%.3f | awk '{if ($1>prev) print prev=$1,$2}' | gmt convert -fi0t -fo0T --FORMAT_CLOCK_OUT=hh:mm:ss.xxx --FORMAT_DATE_OUT=yyyy:jjj --FORMAT_FLOAT_OUT=%.3f | sed -e 's/:/ /g' -e 's/T/ /g' -e 's/./ /18' > $procdir/${id}_rgrav_mgal
        fi
        
    else
        echo "Field $field not found."
	    if [ $field == "dpth" ] && [ ! -s $procdir/${id}_rdpth ] && [ $sample2depthtime -eq 1 ]; then
            echo "No depths - Unable to sample potential field data to depth times."
            sample2depthtime=0
        fi
    fi
done

# Apply 6 minute Gaussian filter to observed gravity and Eotvos here
if [ -s $procdir/${id}_rgrav_mgal ]; then

    # 1. Filter observed gravity
    awk '{printf "%.4d:%.3dT%.2d:%.2d:%.2d.%.3d % 9.3f\n",$1,$2,$3,$4,$5,$6,$7}' $procdir/${id}_rgrav_mgal > $temp.tg
    startt=`head -n 1 $temp.tg | awk '{print $1}' | gmt convert -f0T --FORMAT_DATE_IN=yyyy:jjj --FORMAT_CLOCK_OUT=hh:mm`
    endt=`tail -n 1 $temp.tg | awk '{print $1}'  | gmt convert -f0T --FORMAT_DATE_IN=yyyy:jjj --FORMAT_CLOCK_OUT=hh:mm`
    gmt filter1d $temp.tg -T$startt/$endt/$gnav_si -L$gnav_fw --FORMAT_CLOCK_OUT=hh:mm:ss.xxx --FORMAT_FLOAT_OUT=%.3f -fi0T -fo0t --TIME_UNIT=s --FORMAT_DATE_IN=yyyy:jjj --FORMAT_DATE_OUT=yyyy:jjj -Fg$gnav_fw | sed -e '/>/d' | awk '{if ($1 != 0 && $2 != 0 && NF == 2 && ($2 >= 970000 && $2 <= 990000)) print $0}' > $temp.tg.filt.samp
    # 2. Sample nav at gravity times
    STIME=`gmt info $temp.tg.filt.samp -C --FORMAT_CLOCK_OUT=hh:mm:ss.xxx --FORMAT_FLOAT_OUT=%.3f --FORMAT_DATE_IN=yyyy:jjj | awk '{print $1}' | gmt convert -fo0t`
    ETIME=`gmt info $temp.tg.filt.samp -C --FORMAT_CLOCK_OUT=hh:mm:ss.xxx --FORMAT_FLOAT_OUT=%.3f --FORMAT_DATE_IN=yyyy:jjj | awk '{print $2}' | gmt convert -fo0t`
    if [ $sample2depthtime -eq 0 ]; then # Use grav_sample_interval
        awk '{printf "%04d:%03dT%02d:%02d:%02d.%03d %10.9f %10.9f \n",$1,$2,$3,$4,$5,$6,$9,$8}' $procdir/${id}_pos-mv_clean | gmt convert --FORMAT_CLOCK_IN=hh:mm:ss.xxx --FORMAT_DATE_IN=yyyy:jjj -fi0T -fo0t --FORMAT_FLOAT_OUT=%.12f | awk '{if ($1>prev && ($1>=st && $1<=en)) print prev=$1,$2,$3}' st=$STIME en=$ETIME > $temp.txy
        gmt sample1d $temp.txy -T$temp.tg.filt.samp -Fl -N0 --FORMAT_GEO_OUT=D -fo0t -f1x -f2y --FORMAT_FLOAT_OUT=%.12f | grep -v NaN > $temp.gnav.txy
        STIME=`gmt info $temp.gnav.txy -fi0t -fo0T --FORMAT_DATE_OUT=yyyy:jjj --FORMAT_CLOCK_OUT=hh:mm:ss.xxx -C --FORMAT_FLOAT_OUT=%.12f | awk '{print $1}' | gmt convert -fo0t`
        ETIME=`gmt info $temp.gnav.txy -fi0t -fo0T --FORMAT_DATE_OUT=yyyy:jjj --FORMAT_CLOCK_OUT=hh:mm:ss.xxx -C --FORMAT_FLOAT_OUT=%.12f | awk '{print $2}' | gmt convert -fo0t`
        gmt convert $temp.tg.filt.samp -fi0t -fo0t | awk '($1>=st)&&($1<=en) {print $0}' st=$STIME en=$ETIME > $temp.tg.filt.d
        len1=`wc -l $temp.tg.filt.d | awk '{print $1}'`
        len2=`wc -l $temp.gnav.txy | awk '{print $1}'`
        if [ $len1 != $len2 ]; then
            echo "Warning: nav and grav input files have different lengths" >& 2
            exit
        fi
        paste $temp.tg.filt.d $temp.gnav.txy | awk '{if ($1 == $3) print $1,$4,$5,$2}' | gmt convert -fi0t -fo0T -f1x -f2y --FORMAT_FLOAT_OUT=%.12f --FORMAT_DATE_OUT=yyyy:jjj --FORMAT_CLOCK_OUT=hh:mm:ss.xxx | sed -e 's/:/ /g' -e 's/T/ /g' | awk '{printf "%.4d %.3d %.2d %.2d %06.3f % 3.9f % 3.9f % 7.3f \n",$1,$2,$3,$4,$5,$7,$6,$8}' | sed -e 's/./ /18' > $procdir/${id}_rgrav_mgal+nav
    else # Re-sample to depth times (samples more in shallow water and vice versa)
        awk '{if ($1>prev && ($1>=st && $1<=en)) print prev=$1,$2,$3}' st=$STIME en=$ETIME $temp.dnav.txy.1 > $temp.dnav.txy
        STIME=`gmt info $temp.dnav.txy -C --FORMAT_FLOAT_OUT=%.12f | awk '{print $1}'`
        ETIME=`gmt info $temp.dnav.txy -C --FORMAT_FLOAT_OUT=%.12f | awk '{print $2}'`
        gmt convert $temp.tg.filt.samp -fi0t -fo0t | awk '{if ($1>prev && ($1>=st && $1<=en)) print prev=$1,$2}' st=$STIME en=$ETIME > $temp.tg.filt.samp2
        gmt sample1d $temp.tg.filt.samp2 -T$temp.dnav.txy -Fl -N0 -fi0t --FORMAT_FLOAT_OUT=%.12f | awk '($1>=st)&&($1<=en) {print $0}' st=$STIME en=$ETIME > $temp.tg.filt.samp3
        len1=`wc -l $temp.dnav.txy | awk '{print $1}'`
        len2=`wc -l $temp.tg.filt.samp3 | awk '{print $1}'`
        if [[ ($len1 != $len2  && $len2 -ne 0) ]]; then
            echo "Warning: Sampled gravity and depth nav input files have different lengths" >& 2
            exit
        fi
        paste $temp.tg.filt.samp3 $temp.dnav.txy | awk '{if ($1 == $3) print $1,$4,$5,$2}' | gmt convert -fi0t -fo0T -f1x -f2y --FORMAT_FLOAT_OUT=%.12f --FORMAT_DATE_OUT=yyyy:jjj --FORMAT_CLOCK_OUT=hh:mm:ss.xxx | sed -e 's/:/ /g' -e 's/T/ /g' | awk '{printf "%.4d %.3d %.2d %.2d %06.3f % 3.9f % 3.9f % 7.3f \n",$1,$2,$3,$4,$5,$7,$6,$8}' | sed -e 's/./ /18' > $procdir/${id}_rgrav_mgal+nav
    fi

    if [ -s $procdir/${id}_rgrav_mgal+nav ]; then

        # 3. Use mgd77list to compute normal gravity, raw Eotvos correction and raw free-air anomaly

        # Create temp archive file for mgd77list
        emptyhdr > /tmp/$outid.dat
        $shipcode/udmerge -i $id -g $procdir/${id}_rgrav_mgal+nav | awk '{if ($8 != "nan" && $9 != "nan") print $0}' >> /tmp/$outid.dat
        gmt mgd77list /tmp/$outid.dat -Ftime,lat,lon,gobs,ceot,faa -A+f8,4 --FORMAT_DATE_OUT=yyyy:jjj --FORMAT_CLOCK_OUT=hh:mm:ss.xxx --FORMAT_FLOAT_OUT=%.12f > $temp.greduced.tmp

        # 4. Smooth Eotvos and correct gobs for vessel motion ($9+$10 adds eot to gobs in awk statement)
        awk '{print $1,$5}' $temp.greduced.tmp | gmt filter1d -E -Fg$gnav_fw --FORMAT_CLOCK_OUT=hh:mm:ss.xxx --FORMAT_FLOAT_OUT=%.12f -f0T --TIME_UNIT=s --FORMAT_DATE_IN=yyyy:jjj --FORMAT_DATE_OUT=yyyy:jjj | sed '/>/d' > $temp.teot.filt
        len1=`wc -l $temp.greduced.tmp | awk '{print $1}'`
        len2=`wc -l $temp.teot.filt | awk '{print $1}'`
        if [ $len1 != $len2 ]; then
            echo "Warning: Smoothed Eotvos and gravity files have different lengths" >& 2
            exit
        fi
        paste $temp.greduced.tmp $temp.teot.filt | awk '{print $1,$2,$3,$4,$8,$6}' | sed -e 's/:/ /g' -e 's/T/ /g' -e 's/./ /18' | awk '{printf "%.4d %.3d %.2d %.2d %.2d %.3d % 10.9f % 10.9f % 9.3f % 7.3f % 7.3f\n",$1,$2,$3,$4,$5,$6,$7,$8,$9+$10,$10,$11}' > $procdir/${id}_rgrav_reduced
    
        # 5. With gobs corrected with smoothed Eotvos, calculate free-air anomalies

        # Create temp archive file for mgd77list
        emptyhdr > /tmp/$outid.dat
        $shipcode/udmerge -i $id -g $procdir/${id}_rgrav_reduced | awk '{if ($8 != "nan" && $9 != "nan") print $0}' >> /tmp/$outid.dat
        gmt mgd77list /tmp/$outid.dat -Ftime,lat,lon,gobs,eot,faa -A+f2,4 --FORMAT_DATE_OUT=yyyy:jjj --FORMAT_CLOCK_OUT=hh:mm:ss.xxx --FORMAT_FLOAT_OUT=%.12f | sed -e 's/:/ /g' -e 's/T/ /g' -e 's/./ /18' | awk '{if (($1 <= 2099 && $1 > 1940) && ($2 <= 366 && $2 >= 0) && ($3 <= 23 && $3 >= 0) && ($4 <= 59 && $4 >= 0) && ($5 <= 59 && $5 >= 0) && ($6 <= 999 && $6 >= 0) && ($7 >= -90 && $7 <= 90) && ($8 >= -180.0 && $8 <= 360.0) && ($9 >= 970000 && $9 <= 990000) && ($10 >= -999 && $10 <= 999) && ($11 >= -999 && $11 <= 999) && NF == 11) printf "%.4d %.3d %.2d %.2d %.2d %.3d % 10.9f % 10.9f % 9.3f % 7.3f % 7.3f\n",$1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11}' > $procdir/${id}_rgrav_reduced

        rm -f /tmp/$outid.dat

        if [ -s $procdir/${id}_rgrav_reduced ]; then
            grav="-g $procdir/${id}_rgrav_reduced"
    	else
            echo "Error: gravity reduction calculation failed - abort!"
            exit
        fi
    fi
fi

# Resample magnetics and compute residual magnetic anomalies using mgd77list
if [ -s $procdir/${id}_rmagy_smooth ]; then

    # 2. Sample nav at magy times
    awk '{printf "%.4d:%.3dT%.2d:%.2d:%.2d.%.3d % 9.3f % 5.3f\n",$1,$2,$3,$4,$5,$6,$7,$8}' $procdir/${id}_rmagy_smooth > $temp.tm.filt.samp # Use filtered mag
    STIME=`gmt info $temp.tm.filt.samp -C --FORMAT_DATE_IN=yyyy:jjj --FORMAT_DATE_OUT=yyyy:jjj --FORMAT_CLOCK_OUT=hh:mm:ss.xxx --FORMAT_FLOAT_OUT=%.12f -f0T | awk '{print $1}'`
    ETIME=`gmt info $temp.tm.filt.samp -C --FORMAT_DATE_IN=yyyy:jjj --FORMAT_DATE_OUT=yyyy:jjj --FORMAT_CLOCK_OUT=hh:mm:ss.xxx --FORMAT_FLOAT_OUT=%.12f -f0T | awk '{print $2}'`
    if [ $sample2depthtime -eq 0 ]; then # Use $mag_sample_interval 
        awk '{printf "%04d:%03dT%02d:%02d:%02d.%03d %10.9f %10.9f \n",$1,$2,$3,$4,$5,$6,$9,$8}' $procdir/${id}_pos-mv_clean | gmt convert --FORMAT_CLOCK_IN=hh:mm:ss.xxx --FORMAT_CLOCK_OUT=hh:mm:ss.xxx --FORMAT_DATE_IN=yyyy:jjj --FORMAT_DATE_OUT=yyyy:jjj -f0T --FORMAT_FLOAT_OUT=%.12f | awk '{if ($1>prev && ($1>=st && $1<=en)) print prev=$1,$2,$3}' st=$STIME en=$ETIME > $temp.txy
        gmt sample1d $temp.txy -T$temp.tm.filt.samp -Fl -N0 --TIME_UNIT=s --FORMAT_GEO_OUT=D -f0T -f1x -f2y --FORMAT_FLOAT_OUT=%.12f --FORMAT_DATE_IN=yyyy:jjj --FORMAT_DATE_OUT=yyyy:jjj --FORMAT_CLOCK_OUT=hh:mm:ss.xxx | grep -v NaN > $temp.mnav.txy
        STIME=`gmt info $temp.mnav.txy -C -f0T --FORMAT_FLOAT_OUT=%.12f --FORMAT_DATE_IN=yyyy:jjj --FORMAT_DATE_OUT=yyyy:jjj --FORMAT_CLOCK_OUT=hh:mm:ss.xxx | awk '{print $1}'`
        ETIME=`gmt info $temp.mnav.txy -C -f0T --FORMAT_FLOAT_OUT=%.12f --FORMAT_DATE_IN=yyyy:jjj --FORMAT_DATE_OUT=yyyy:jjj --FORMAT_CLOCK_OUT=hh:mm:ss.xxx | awk '{print $2}'`
        awk '($1>=st)&&($1<=en) {print $0}' st=$STIME en=$ETIME  $temp.tm.filt.samp  > $temp.tm.d
        len1=`wc -l $temp.tm.d | awk '{print $1}'`
        len2=`wc -l $temp.mnav.txy | awk '{print $1}'`
        if [ $len1 != $len2 ]; then
            echo "Warning: nav and magy input files have different lengths" >& 2
            exit
        fi
	    # order of mag fields: mtf1 mag diur msd (assume no mtf2 and msens unspecified means single sensor)
        paste $temp.tm.d $temp.mnav.txy | awk '{if ($1 == $4) print $1,$5,$6,$2,$3}' | sed -e 's/:/ /g' -e 's/T/ /g' | awk '{printf "%.4d %.3d %.2d %.2d %06.3f % 3.9f % 3.9f % 7.3f nan nan % 5.3f\n",$1,$2,$3,$4,$5,$7,$6,$8,$9}' | sed -e 's/./ /18' > $procdir/${id}_rmagy_smooth+nav
    else # Sample at all depth record times 
        gmt convert -fi0t -fo0T --FORMAT_DATE_OUT=yyyy:jjj --FORMAT_CLOCK_OUT=hh:mm:ss.xxx --FORMAT_FLOAT_OUT=%.12f $temp.dnav.txy.1 | awk '{if ($1>prev && ($1>=st && $1<=en)) print prev=$1,$2,$3}' st=$STIME en=$ETIME > $temp.dnav.Txy
        STIME=`gmt info $temp.dnav.Txy -C --FORMAT_DATE_IN=yyyy:jjj --FORMAT_DATE_OUT=yyyy:jjj --FORMAT_CLOCK_OUT=hh:mm:ss.xxx --FORMAT_FLOAT_OUT=%.12f -f0T | awk '{print $1}'`
        ETIME=`gmt info $temp.dnav.Txy -C --FORMAT_DATE_IN=yyyy:jjj --FORMAT_DATE_OUT=yyyy:jjj --FORMAT_CLOCK_OUT=hh:mm:ss.xxx --FORMAT_FLOAT_OUT=%.12f -f0T | awk '{print $2}'`
        gmt sample1d $temp.tm.filt.samp -T$temp.dnav.Txy -Fl -N0 -f0T --FORMAT_FLOAT_OUT=%.3f --FORMAT_DATE_IN=yyyy:jjj --FORMAT_DATE_OUT=yyyy:jjj --FORMAT_CLOCK_OUT=hh:mm:ss.xxx | awk '($1>=st)&&($1<=en) {print $0}' st=$STIME en=$ETIME > $temp.tm.filt.samp2
        len1=`wc -l $temp.dnav.Txy | awk '{print $1}'`
        len2=`wc -l $temp.tm.filt.samp2 | awk '{print $1}'`
        if [ $len1 != $len2 ]  && [ $len2 -ne 0 ]; then
            echo "Warning: Sampled magnetic and depth nav input files have different lengths" >& 2
            exit
        fi
        paste $temp.tm.filt.samp2 $temp.dnav.Txy | awk '{if ($1 == $4) print $1,$5,$6,$2,$3}' | sed -e 's/:/ /g' -e 's/T/ /g' | awk '{printf "%.4d %.3d %.2d %.2d %06.3f % 3.9f % 3.9f % 9.3f nan nan % 5.3f\n",$1,$2,$3,$4,$5,$7,$6,$8,$9,$10,$11}' | sed -e 's/./ /18' > $procdir/${id}_rmagy_smooth+nav
    fi

    if [ -s $procdir/${id}_rmagy_smooth+nav ]; then
        
        if [ $compute_diurnal_correction -eq 1 ]; then
            # 2. Compute diurnal correction using CM4 via mgd77magref
            awk '{printf "%s %s %s-%sT%s:%s:%s.%s\n",$8,$7,$1,$2,$3,$4,$5,$6}' $procdir/${id}_rmagy_smooth+nav | gmt convert -f2T --FORMAT_DATE_IN=yyyy-jjj --FORMAT_DATE_OUT=yyyy-mm-dd --FORMAT_CLOCK_OUT=hh:mm:ss.xxx | gmt mgd77magref -A+a0 -Frt/3456 --FORMAT_CLOCK_OUT=hh:mm:ss.xxx | awk '{print $3,$4}' | gmt convert -f0T --FORMAT_DATE_OUT=yyyy:jjj --FORMAT_DATE_IN=yyyy-mm-dd --FORMAT_CLOCK_OUT=hh:mm:ss.xxx | sed -e 's/:/ /g' -e 's/T/ /g' -e 's/./ /18' > $temp.diur
            len1=`wc -l $procdir/${id}_rmagy_smooth+nav | awk '{print $1}'`
            len2=`wc -l $temp.diur | awk '{print $1}'`
            if [ $len1 != $len2 ]  && [ $len2 -ne 0 ]; then
                echo "Warning: ${id}_rmagy_smooth+nav and diurnal correction files have different lengths" >& 2
                exit
            fi
            paste $procdir/${id}_rmagy_smooth+nav $temp.diur | awk '{t1=$1$2$3$4$5$6; t2=$13$14$15$16$17$18; if ( t1 == t2) printf "%.4d %.3d %.2d %.2d %.2d %.3d % 3.9f % 3.9f % 9.3f nan % 5.3f % 5.3f\n",$1,$2,$3,$4,$5,$6,$7,$8,$9,$19,$12}' > $temp.${id}_rmagy_smooth+nav
            if [ -s $temp.${id}_rmagy_smooth+nav ]; then
                \cp -f $temp.${id}_rmagy_smooth+nav $procdir/${id}_rmagy_smooth+nav
            fi
        fi

        # 3. Create a temporary gmt dat file containing only nav and mag
        emptyhdr > /tmp/$outid.dat
        $shipcode/udmerge -i $id -m $procdir/${id}_rmagy_smooth+nav | awk '{if ($8 != "nan" && $9 != "nan" && $15 != "nan") print $0}' >> /tmp/$outid.dat

        # 4. Use mgd77list to compute magnetic anomalies ($10+$11 in awk command applies diurnal correction)
        gmt mgd77list /tmp/$outid.dat -Ftime,lat,lon,mtf1,mag,diur,msd,'mtf1!=NaN' -A+m2 --FORMAT_GEO_OUT=D --FORMAT_DATE_OUT=yyyy:jjj --FORMAT_CLOCK_OUT=hh:mm:ss.xxx --FORMAT_FLOAT_OUT=%.12f | sed -e 's/:/ /g' -e 's/T/ /g' -e 's/./ /18' | awk '{if ($1 != 0 && $9 != 0 && $10 != 0 && NF == 12 && ($9 >= 15000 && $9 <= 75000) && ($10 >= -999 && $10 <= 999)) printf "%.4d %.3d %.2d %.2d %.2d %.3d % 3.9f % 3.9f % 9.3f % 7.3f % 7.3f % 7.3f\n",$1,$2,$3,$4,$5,$6,$7,$8,$9,$10+$11,$11,$12}' > $procdir/${id}_rmagy_reduced

        rm -f /tmp/$outid.dat

        if [ -s $procdir/${id}_rmagy_reduced ]; then
            mag="-m $procdir/${id}_rmagy_reduced"
        else
            echo "Error: magnetic reduction calculation failed - abort!"
            exit
        fi
    fi
fi

# Now for the fun part, merge the data
nav=""
dpth=""
mag=""
grav=""

if [ -s $procdir/${id}_cdpth ]; then
    dpth="-d $procdir/${id}_cdpth"
fi

if [ -s $procdir/${id}_rmagy_reduced ]; then
    mag="-m $procdir/${id}_rmagy_reduced"
fi

if [ -s $procdir/${id}_rgrav_reduced ]; then
    grav="-g $procdir/${id}_rgrav_reduced"
fi
$shipcode/udmerge -i $id $nav $dpth $mag $grav | awk '{if ($8 != "nan" && $9 != "nan") print $0}' > $outid.dat

# MGD77 header (check for h77 file in $dpath/h77 or use dummy)
# Create a custom header items file for mgd77header -H option
echo "Survey_Identifier ${id:0:7}" > $temp.hdrpar.txt
echo "Platform_Type_Code 1" >> $temp.hdrpar.txt
echo "Platform_Type SHIP" >> $temp.hdrpar.txt
echo "Country ${country:0:17}" >> $temp.hdrpar.txt
echo "Source_Institution ${source_institution:0:38}" >> $temp.hdrpar.txt
echo "Funding ${funder:0:19}" >> $temp.hdrpar.txt
echo "Chief_Scientist ${chiefsci:0:31}" >> $temp.hdrpar.txt
echo "Platform_Name ${vessel:0:20}" >> $temp.hdrpar.txt
echo "Project_Cruise_Leg ${project_cruise_leg:0:57}" >> $temp.hdrpar.txt
echo "Port_of_Departure ${port1:0:31}" >> $temp.hdrpar.txt
echo "Port_of_Arrival ${port2:0:29}" >> $temp.hdrpar.txt
echo "Data_Center_File_Number ${outid:0:7}" >> $temp.hdrpar.txt # cruise id as temp data center number
echo "Navigation_Instrumentation ${navinstr:0:39}" >> $temp.hdrpar.txt
sonarinstr="$sonar1$sonar2"
echo "Bathymetry_Instrumentation ${sonarinstr:0:39}" >> $temp.hdrpar.txt
echo "Gravity_Instrumentation ${gravimeter:0:39}" >> $temp.hdrpar.txt
echo "Gravity_Sampling_Rate 0" >> $temp.hdrpar.txt
echo "Gravity_Digitizing_Rate 0" >> $temp.hdrpar.txt
echo "Magnetics_Instrumentation ${magnetometer:0:39}" >> $temp.hdrpar.txt
echo "Magnetics_Digitizing_Rate 0" >> $temp.hdrpar.txt
echo "Additional_Documentation_3 OBSERVATION LOCATIONS INTERPOLATED FROM GPS VIA LINEAR INTERPOLATION" >> $temp.hdrpar.txt

if [ $sample2depthtime -eq 0 ]; then
    if [ -s $procdir/${id}_rmagy_reduced ]; then
            echo "Additional_Documentation_6 MAGNETICS ${mag_fw} S GAUSSIAN FILTER, DIGITIZED AT $mag_sample_interval S INTERVALS" >> $temp.hdrpar.txt
    fi
        if [ -s $procdir/${id}_rgrav_reduced ]; then
        echo "Additional_Documentation_7 GRAVITY ${gnav_fw} S GAUSSIAN FILTER, DIGITIZED AT $gnav_si S INTERVALS" >> $temp.hdrpar.txt
    fi
else
    if [ -s $procdir/${id}_rmagy_reduced ]; then
        echo "Additional_Documentation_6 MAGNETICS ${mag_fw} S GAUSSIAN FILTER, DIGITIZED AT DEPTH TIMES" >> $temp.hdrpar.txt
    fi
        if [ -s $procdir/${id}_rgrav_reduced ]; then
        echo "Additional_Documentation_7 GRAVITY ${gnav_fw} S GAUSSIAN FILTER, DIGITIZED AT DEPTH TIMES" >> $temp.hdrpar.txt
    fi
fi

if [ -s $outputdatapath/h77/$outid.h77 ]; then
    cat $outputdatapath/h77/$outid.h77 > $temp.$outid.h77
else
    gmt mgd77header -H$temp.hdrpar.txt $outid.dat -Mr > $temp.$outid.h77
fi

mv -f $outid.dat $temp.$outid.dat

cat $temp.$outid.h77 $temp.$outid.dat > $orig.dat

gmt mgd77convert $outid.dat -Ft -T+m
if [ -s $outid.m77t ]; then
    mv -f $outid.m77t $outputdatapath
fi

gmt mgd77convert $outid.dat -Ft -T+c
if [ -s $outid.nc ]; then
    mv -f $outid.nc $outputdatapath
fi

if [ -s $orig.dat ]; then
   mv -f $orig.dat $outputdatapath
fi

rm -f $temp.*
