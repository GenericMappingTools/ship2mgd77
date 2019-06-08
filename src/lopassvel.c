/*
 
 lopassvel.c
 M. T. Chandler
 Hawaii Institute of Geophysics and Planetology
 University of Hawaii
 June 2013
 
 Low Pass Velocity: Remove navigation records containing speed jumps that exceed a given threshold
 
 To compile: cc lopassvel.c -o lopassvel
 
 Usage: lopassvel n_navrecs threshold_value_kts < raw_nav_file 
 
 Note: Input are as follows (time (in seconds) lat lon)
 # e.g. 473299201.24    57.709380    -152.147988

*/

#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <math.h>

int main (int argc, char **argv)
{
    if ( argc != 2 && argc != 3 ) {

        /* We print argv[0] assuming it is the program name */
        printf( "usage: %s <n_records> [output suppression threshold in knots (default returns all records)]", argv[0] );
        exit(0);
    }
    else
    {
        int nrecs = 0;
        float threshold = 0.0;
        nrecs = atoi(argv[1]);
        
        if (argc == 3) threshold = atof(argv[2]);

        if ( nrecs <= 0 )
        {
            printf( "No records found %d\n",nrecs );
            exit(0);
        }
    
        double *ss, *lon, *lat, *v;
        ss = calloc (nrecs, (sizeof(double)));
        lon = calloc (nrecs, (sizeof(double)));
        lat = calloc (nrecs, (sizeof(double)));
        v = calloc (nrecs, (sizeof(double)));
        double lat2, tj, ti, dt, dy, dx, d, prevspd;
        int i, j;
        
        /* For each input record */
        for (i = 0; i < nrecs; i++) {
            
            /* Store time, lat and lon */
            scanf("%lg %lg %lg", &ss[i],&lat[i],&lon[i]);
            if (i > 0) {
                
                /* Search for previous good record */
                for (j = i-1; lat[j]==-90 && j >= 0; j--) continue;
                if (lat[j] == -90) continue;
                
                /* Convert degrees to radians */
                lat2 = lat[i] * atan2(0,-1) / 180;
                
                /* Compute time gap in hours */
                dt = (ss[i]-ss[j])/60/60;
                
                /* Compute lat gap in nautical miles */
                dy = (lat[i]-lat[j])*60;
                
                /* Compute lon gap in nautical miles, with latitude correction */
                dx = (lon[i]-lon[j])*60*cos(lat2);
                
                /* Compute distance in nautical miles */
                d = sqrt(dx*dx+dy*dy);
                
                /* Calculate speed in knots */
                if (dt != 0) {
                    v[i]=d/dt;
                } else
                    v[i]=MAXFLOAT;
                
                /* Check if speed is out of range */
                if (threshold != 0 && (v[i] > threshold || v[i] < 0)) {
                    if (prevspd <= threshold || v[i]<0){
                        lat[i] = -90;
                    } else {
                        lat[j] = -90;
                    }
                } else {
                    prevspd = v[i];
                }
            }
        }
        /* First speed cell empty, copy from second */
        v[0]=v[1];

        /* Output time, lat, lon, and speed */
        for (i=0;i<nrecs;i++){
            if (v[i] <= threshold || threshold == 0) printf ("%.6f %.6f %.6f %.1f\n",ss[i],lat[i],lon[i],v[i]);
        }
    }
}
