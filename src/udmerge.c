/*
 
 udmerge.c
 M. T. Chandler
 Hawaii Institute of Geophysics and Planetology
 University of Hawaii
 May 2012
 
 Underway Data Merge: merge underway depth, magnetic, and gravity data with pos-mv navigation.
 
 To compile: cc -o udmerge udmerge.c
 
 Usage: udmerge -i <cruiseid> [-n /path/cruiseid_pos-mv] [-d /path/cruiseid_cdpth] [-m /path/cruiseid_cmagy] [-g /path/cruiseid_cgrav]
 
 Note: -i option required. One or more of n, d, m and g options required.
 
 Input data follow SOEST convention for corrected data:
 
 For example:
 
 ==> km1609_pos-mv <==
 2016 342 00 00 00 496 *gpo  -7.032306 -175.930304  0.80 11.80 291.50 11 2 297.35  0.50  1.02  0.55
 2016 342 00 00 00 996 *gpo  -7.032296 -175.930329  0.80 11.90 291.70 11 2 297.32  0.61  0.86  0.50
 2016 342 00 00 01 496 *gpo  -7.032285 -175.930355  0.80 11.90 292.20 11 2 297.30  0.68  0.74  0.41
...
 
 ==> km1609_rbgm3grav <==
 2016 342 00 00 00 863 rbgm3 024945 00 126551.749715
 2016 342 00 00 01 863 rbgm3 024193 00 122736.679930
 2016 342 00 00 02 864 rbgm3 023700 00 120235.576999
...
 
 ==> km1609_rdpth <==
 2016 342 00 00 04 321 dpth    5790.4546      0.00
 2016 342 00 00 04 530 dpth    5775.2310      0.00
 2016 342 00 00 24 953 dpth    5774.8188      0.00
...
 
 ==> km1609_rmagy <==
 2016 342 01 54 33 229 magy 35925.875 1699  2.76
 2016 342 01 54 33 324 magy 35925.875 1707  2.78
 2016 342 01 54 33 424 magy 35925.891 1682  2.73
...
 

 */

#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <stdio.h>

#ifndef MAXFLOAT
	#ifdef FLT_MAX
		#define MAXFLOAT FLT_MAX
	#else
		#define MAXFLOAT 3.40282347E+38F
	#endif
#endif
#define DECYR_SLOP 1.90134e-9 /* The maximum time precision for MGD77 data, 0.06 seconds (1/60/60/24/365.24*.06) or 1.90134e-9 yr */

/* #define DEBUG  */

struct RECORD {
    int rec;
    int tz;
    int yy;
    int jjj;
    int hh;
    int mm;
    double ss;
    double lat;
    double lon;
    char ptc;
    double twt;
    double depth;
    char bcc[4]; 
    char btc;
    double mtf1;
    double mtf2;
    float mag;
    char msens;
    double diur;
    float msd;
    double dial;
    double dialmgal;
    double gobs;
    double eot;
    double faa;
    char nqc;
    char id[BUFSIZ];
    char sln[BUFSIZ];
    char sspn[BUFSIZ];
    double decyr;
    double prevdecyr;
    char line[BUFSIZ];
    FILE *input;
    char field;
    int use;
};

void kmoutput (struct RECORD *);
int setoutput (struct RECORD  *, struct RECORD  *, struct RECORD  *);
void reset (struct RECORD *, struct RECORD *);
int read (char *, struct RECORD *, FILE *, char *, int);
double decyear(int *, int *, int *, int *, double *);
int ordday2mo (int, int);
int ordday2dd (int, int);
int isleapyear(int), dread, mread, gread, nread;

int main(int argc, char **argv)
{
	char ninfile[BUFSIZ], dinfile[BUFSIZ], minfile[BUFSIZ], ginfile[BUFSIZ], cruiseid[BUFSIZ];
    char pingno[BUFSIZ];
	int i, error=0, nfields=0;

    struct RECORD nrec[33]  = {
        /*drt, tz,  yy,jjj, hh, mm, ss,lat,lon,ptc,twt,depth,   bcc,btc,mtf1,mtf2,mag,msens,diur,msd,dial,dialmgal,gobs,eot,faa,nqc,  id,    sln,    sspn,   decyr, prevdecyr, line, input,field, use */
        {   5,  0,   0,  0,  0,  0,  NAN,NAN,NAN,'9',NAN,  NAN,"99\0",'9', NAN, NAN,NAN,  '9', NAN,NAN, NAN,     NAN, NAN,NAN,NAN,'9',"KM","99999","999999",MAXFLOAT, MAXFLOAT, "\0",  NULL,  'n', 0}
    };
    struct RECORD drec[33]  = {
        /*drt, tz,  yy,jjj, hh, mm, ss,lat,lon,ptc,twt,depth,   bcc,btc,mtf1,mtf2,mag,msens,diur,msd,dial,dialmgal,gobs,eot,faa,nqc,  id,    sln,    sspn,   decyr, prevdecyr, line, input,field, use */
        {   5,  0,   0,  0,  0,  0,  NAN,NAN,NAN,'9',NAN,  NAN,"99\0",'9', NAN, NAN,NAN,  '9', NAN,NAN, NAN,     NAN, NAN,NAN,NAN,'9',"KM","99999","999999",MAXFLOAT, MAXFLOAT, "\0",  NULL,  'd', 0}
    };
    struct RECORD mrec[33]  = {
        /*drt, tz,  yy,jjj, hh, mm, ss,lat,lon,ptc,twt,depth,   bcc,btc,mtf1,mtf2,mag,msens,diur,msd,dial,dialmgal,gobs,eot,faa,nqc,  id,    sln,    sspn,   decyr, prevdecyr, line, input,field, use */
        {   5,  0,   0,  0,  0,  0,  NAN,NAN,NAN,'9',NAN,  NAN,"99\0",'9', NAN, NAN,NAN,  '9', NAN,NAN, NAN,     NAN, NAN,NAN,NAN,'9',"KM","99999","999999",MAXFLOAT, MAXFLOAT, "\0",  NULL,  'm', 0}
    };
    struct RECORD grec[33]  = {
        /*drt, tz,  yy,jjj, hh, mm, ss,lat,lon,ptc,twt,depth,   bcc,btc,mtf1,mtf2,mag,msens,diur,msd,dial,dialmgal,gobs,eot,faa,nqc,  id,    sln,    sspn,   decyr, prevdecyr, line, input,field, use */
        {   5,  0,   0,  0,  0,  0,  NAN,NAN,NAN,'9',NAN,  NAN,"99\0",'9', NAN, NAN,NAN,  '9', NAN,NAN, NAN,     NAN, NAN,NAN,NAN,'9',"KM","99999","999999",MAXFLOAT, MAXFLOAT, "\0",  NULL,  'g', 0}
    };
    struct RECORD outrec[33]  = {
        /*drt, tz,  yy,jjj, hh, mm, ss,lat,lon,ptc,twt,depth,   bcc,btc,mtf1,mtf2,mag,msens,diur,msd,dial,dialmgal,gobs,eot,faa,nqc,  id,    sln,    sspn,   decyr, prevdecyr, line, input,field, use */
        {   5,  0,   0,  0,  0,  0,  NAN,NAN,NAN,'9',NAN,  NAN,"99\0",'9', NAN, NAN,NAN,  '9', NAN,NAN, NAN,     NAN, NAN,NAN,NAN,'9',"KM","99999","999999",MAXFLOAT, MAXFLOAT, "\0",  NULL, '\0', 0}
    };
     struct RECORD initial[33]  = {
        /*drt, tz,  yy,jjj, hh, mm, ss,lat,lon,ptc,twt,depth,   bcc,btc,mtf1,mtf2,mag,msens,diur,msd,dial,dialmgal,gobs,eot,faa,nqc,  id,    sln,    sspn,   decyr, decyr, prevdecyr, line, input,field, use */
        {   5,  0,   0,  0,  0,  0,  NAN,NAN,NAN,'9',NAN,  NAN,"99\0",'9', NAN, NAN,NAN,  '9', NAN,NAN, NAN,     NAN, NAN,NAN,NAN,'9',"KM","99999","999999",MAXFLOAT, MAXFLOAT, "\0",  NULL, '\0', 0}
    };
    struct RECORD *current = NULL;
    drec->decyr = mrec->decyr = grec->decyr = MAXFLOAT;

	for (i = 1; !error && i < argc; i++) {	/* Process infiles */
		if (argv[i][0] != '-') continue;
		switch (argv[i][1]) {
            case 'i':
            strcpy (cruiseid,&argv[i][3]);
                if (!strcmp(cruiseid,"")) {
					fprintf(stderr,"*** Invalid cruise id ***\n");
					exit(0);                    
                }
                break;
			case 'n':
				strcpy (ninfile,&argv[i][3]);
				nrec->input = fopen(ninfile, "r");
				if (nrec->input == NULL) {
					fprintf(stderr,"*** Can't open pos-mv input file ***\n");
					exit(0);
				}
                read (nrec->line, nrec, nrec->input, "n", 0);
                nrec->use=1; nfields++;
                nrec->prevdecyr = nrec->decyr;
				break;
			case 'd':
				strcpy (dinfile,&argv[i][3]);
				drec->input = fopen(dinfile, "r");
				if (drec->input == NULL) {
					fprintf(stderr,"*** Can't open depth input file ***\n");
					exit(0);
				}
                read (drec->line, drec, drec->input, "d", 0);
                drec->use=1; nfields++;
                drec->prevdecyr = drec->decyr;
				break;
			case 'm':
				strcpy (minfile,&argv[i][3]);
				mrec->input = fopen(minfile, "r");
				if (mrec->input == NULL) {
					fprintf(stderr,"*** Can't open magnetic input file ***\n");
					exit(0);
				}
                read (mrec->line,mrec,mrec->input, "m", 0);
                mrec->use=1; nfields++;
                mrec->prevdecyr = mrec->decyr;
				break;
			case 'g':
				strcpy (ginfile,&argv[i][3]);
				grec->input = fopen(ginfile, "r");
				if (grec->input == NULL) {
					fprintf(stderr,"*** Can't open gravity input file ***\n");
					exit(0);
				}
                read (grec->line,grec,grec->input, "g", 0);
                grec->use=1; nfields++;
                grec->prevdecyr = grec->decyr;
				break;
			default:		/* Options not recognized */
				error = 1;
				break;
		}
	}

	if (error || nfields < 1 || nfields > 4) {	/* Display usage */
		fprintf(stderr,"udmerge - Merge cruiseid_cdpth, cruiseid_cmagy, and cruiseid_cgrav files.\n\n");
		fprintf(stderr,"usage: udmerge -i <cruiseid> [-n cruiseid_pos-mv] [-d cruiseid_cdpth] [-m cruiseid_cmagy] [-g cruiseid_cgrav]\n\n");
        fprintf(stderr,"\t-i option required. One or more of n, d, m and g options required. \n");
		fprintf(stderr,"\tInput files use SOEST formats for corrected underway data.\n\n");
        fprintf(stderr,"\tFor example:\n\n");
        
        fprintf(stderr,"\t==> km1609_pos-mv <==\n");
        fprintf(stderr,"\t2016 342 00 00 00 496 *gpo  -7.032306 -175.930304  0.80 11.80 291.50 11 2 297.35  0.50  1.02  0.55\n");
        fprintf(stderr,"\t2016 342 00 00 00 996 *gpo  -7.032296 -175.930329  0.80 11.90 291.70 11 2 297.32  0.61  0.86  0.50\n");
        fprintf(stderr,"\t2016 342 00 00 01 496 *gpo  -7.032285 -175.930355  0.80 11.90 292.20 11 2 297.30  0.68  0.74  0.41\n");
        fprintf(stderr,"\t...\n\n");
        
        fprintf(stderr,"\t==> km1609_rbgm3grav <==\n");
        fprintf(stderr,"\t2016 342 00 00 00 863 rbgm3 024945 00 126551.749715\n");
        fprintf(stderr,"\t2016 342 00 00 01 863 rbgm3 024193 00 122736.679930\n");
        fprintf(stderr,"\t2016 342 00 00 02 864 rbgm3 023700 00 120235.576999\n");
        fprintf(stderr,"\t...\n\n");
        
        fprintf(stderr,"\t==> km1609_rdpth <==\n");
        fprintf(stderr,"\t2016 342 00 00 04 321 dpth    5790.4546      0.00\n");
        fprintf(stderr,"\t2016 342 00 00 04 530 dpth    5775.2310      0.00\n");
        fprintf(stderr,"\t2016 342 00 00 24 953 dpth    5774.8188      0.00\n");
        fprintf(stderr,"\t...\n\n");
        
       fprintf(stderr,"\t ==> km1609_rmagy <==\n");
       fprintf(stderr,"\t2016 342 01 54 33 229 magy 35925.875 1699  2.76\n");
       fprintf(stderr,"\t2016 342 01 54 33 324 magy 35925.875 1707  2.78\n");
       fprintf(stderr,"\t2016 342 01 54 33 424 magy 35925.891 1682  2.73\n");
		exit (0);
	}
    
    printf ("#rec	TZ	year	month	day	hour	min.xxx lat		lon		ptc	twt	depth	bcc	btc	mtf1	mtf2	mag	msens	diur	msd	gobs	eot	faa	nqc	id	sln	sspn\n");
    strcpy (outrec->id,cruiseid);
    current = nrec->decyr <= drec->decyr ? nrec: drec;
    if (current->decyr >= mrec->decyr) current = mrec;
    current = current->decyr <= grec->decyr ? current : grec;
    i = 0;
    while (nrec->use + drec->use + mrec->use + grec->use) {
        nread = dread = mread = gread = 0;
        if (nrec->use && setoutput (nrec,current,outrec)) nread=1;
        if (drec->use && setoutput (drec,current,outrec)) dread=1;
        if (mrec->use && setoutput (mrec,current,outrec)) mread=1;
        if (grec->use && setoutput (grec,current,outrec)) gread=1;
        #ifdef DEBUG
        if (nrec->use)
            fprintf (stdout, "recno: %d, nread: %d, current=: %.08f, nrec=: %.08f nrec->decyr-nrec->prevdecyr (%.12f) >= DECYR_SLOP(%.12f)? %d\n",i,nread,current->decyr,nrec->decyr,nrec->decyr-nrec->prevdecyr,DECYR_SLOP,nrec->decyr-nrec->prevdecyr >= DECYR_SLOP);
        if (drec->use)
            fprintf (stdout, "recno: %d, dread: %d, current=: %.08f, drec=: %.08f drec->decyr-drec->prevdecyr (%.12f) >= DECYR_SLOP(%.12f)? %d\n",i,dread,current->decyr,drec->decyr,drec->decyr-drec->prevdecyr,DECYR_SLOP,drec->decyr-drec->prevdecyr >= DECYR_SLOP);
        if (mrec->use)
            fprintf (stdout, "recno: %d, mread: %d, current=: %.08f, mrec=: %.08f mrec->decyr-mrec->prevdecyr (%.12f) >= DECYR_SLOP(%.12f)? %d\n",i,mread,current->decyr,mrec->decyr,mrec->decyr-mrec->prevdecyr,DECYR_SLOP,mrec->decyr-mrec->prevdecyr >= DECYR_SLOP);
        if (grec->use)
            fprintf (stdout, "recno: %d, gread: %d, current=: %.08f, grec=: %.08f grec->decyr-grec->prevdecyr (%.12f) >= DECYR_SLOP(%.12f)? %d\n",i,gread,current->decyr,grec->decyr,grec->decyr-grec->prevdecyr,DECYR_SLOP,grec->decyr-grec->prevdecyr >= DECYR_SLOP);
        #endif
        kmoutput (outrec);
        reset (outrec,initial);
        if (nread) {
            nrec->prevdecyr=nrec->decyr;
            if (! read (nrec->line,nrec,nrec->input, "n", i)) {
                reset (nrec,initial);
                nrec->use=0;
            }
        }
        if (dread) {
            drec->prevdecyr=drec->decyr;
            if (! read (drec->line,drec,drec->input, "d", i)) {
                reset (drec,initial);
                drec->use=0;
            }
        }
        if (mread) {
            mrec->prevdecyr=mrec->decyr;
            if (! read (mrec->line,mrec,mrec->input, "m", i)) {
                reset (mrec,initial);
                mrec->use=0;
            }
        }
        if (gread) {
            grec->prevdecyr=grec->decyr;
            if (! read (grec->line,grec,grec->input, "g", i)) {
                reset (grec,initial);
                grec->use=0;
            }
        }
        current = nrec->decyr <= drec->decyr ? nrec: drec;
        if (current->decyr >= mrec->decyr) current = mrec;
        current = current->decyr <= grec->decyr ? current : grec;
        i++;
    }
    
	/* close files */
	if (nrec->input) fclose(nrec->input);
	if (drec->input) fclose(drec->input);
	if (mrec->input) fclose(mrec->input);
	if (grec->input) fclose(grec->input);
}

void kmoutput (struct RECORD *out)
{
    printf ("%d\t%d\t%d\t%d\t%d\t%d\t%06.6f\t%.9f\t%.9f\t%c\t%f\t%f\t%s\t%c\t%f\t%f\t%f\t%c\t%f\t%f\t%.2f\t%f\t%f\t%c\t%s\t%s\t%s\n",out->rec,out->tz,out->yy,ordday2mo(out->jjj,out->yy),ordday2dd(out->jjj,out->yy),out->hh,out->mm+(out->ss/60.0),
    out->lat,out->lon,out->ptc,out->twt,out->depth,out->bcc,out->btc,out->mtf1,out->mtf2,out->mag,out->msens,out->diur,out->msd,out->gobs,out->eot,out->faa,out->nqc,out->id,out->sln,out->sspn);
}

int setoutput (struct RECORD *rec, struct RECORD *curr, struct RECORD *out)
{
    #ifdef DEBUG
    fprintf (stdout,"(%d) rec->field= %c, rec->decyr=: %.012f, curr->decyr=: %.012f r_decyr-curr_decyr: %.12f (slop factor: %.12f)\n",rec->decyr == curr->decyr,rec->field,rec->decyr,curr->decyr,fabs(rec->decyr-curr->decyr),DECYR_SLOP);
    #endif
    /* All data within DECYR_SLOP time increment (.06 sec) should be output to one record */
    /* Note: 0.06 seconds (.001 minutes) is the MGD77 format's maximum temporal precision */
    if (rec->decyr >= curr->decyr-DECYR_SLOP && rec->decyr <= curr->decyr+DECYR_SLOP) {
        switch (rec->field) {
            case 'd':
                out->decyr = rec->decyr;
                out->yy = rec->yy;
                out->jjj = rec->jjj;
                out->hh = rec->hh;
                out->mm = rec->mm;
                out->ss = rec->ss;
                out->lat = rec->lat;
                out->lon = rec->lon;
                out->depth = rec->depth;
                break;
            case 'm':
                out->decyr = rec->decyr;
                out->yy = rec->yy;
                out->jjj = rec->jjj;
                out->hh = rec->hh;
                out->mm = rec->mm;
                out->ss = rec->ss;
                out->lat = rec->lat;
                out->lon = rec->lon;
                out->mtf1 = rec->mtf1;
                out->mtf2 = rec->mtf2;
                out->mag = rec->mag;
                out->msens = rec->msens;
                out->diur = rec->diur;
                out->msd = rec->msd;
                break;
            case 'g':
                out->decyr = rec->decyr;
                out->yy = rec->yy;
                out->jjj = rec->jjj;
                out->hh = rec->hh;
                out->mm = rec->mm;
                out->ss = rec->ss;
                out->lat = rec->lat;
                out->lon = rec->lon;
                out->eot = rec->eot;
                out->faa = rec->faa;
                out->gobs = rec->gobs;
                break;
            default: /* Nav only case */
                out->decyr = rec->decyr;
                out->yy = rec->yy;
                out->jjj = rec->jjj;
                out->hh = rec->hh;
                out->mm = rec->mm;
                out->ss = rec->ss;
                out->lat = rec->lat;
                out->lon = rec->lon;
                break;
        }
        return 1;
    } else return 0;
}

void reset (struct RECORD *old, struct RECORD *new)
{
    old->tz=new->tz;
    old->yy=new->yy;
    old->jjj=new->jjj;
    old->hh=new->hh;
    old->mm=new->mm;
    old->ss=new->ss;
    old->lat=new->lat;
    old->lon=new->lon;
    old->twt=new->twt;
    old->depth=new->depth;
    old->mtf1=new->mtf1;
    old->msd=new->msd;
    old->mag=new->mag;
    old->diur=new->diur;
    old->dial=new->dial;
    old->dialmgal=new->dialmgal;
    old->gobs=new->gobs;
    old->eot=new->eot;
    old->faa=new->faa;
    old->decyr=new->decyr;
    strcpy(old->line,new->line);
    old->field=new->field;
}

int read (char line[BUFSIZ], struct RECORD *rec, FILE *file, char *field, int recno)
{
    int xxx;
    float sigstrength;
    
    if (fgets (line,BUFSIZ,file)) {
        switch (*field) {
            case 'n':
                sscanf (line,"%d %d %d %d %lg %d %*s %lf %lf",&rec->yy,&rec->jjj,&rec->hh,&rec->mm,&rec->ss,&xxx,&rec->lat,&rec->lon);
                rec->ss+=xxx/1000.0;
                rec->decyr = decyear (&rec->yy,&rec->jjj,&rec->hh,&rec->mm,&rec->ss);
                #ifdef DEBUG
                fprintf (stdout,"PASS: recno: %d rec->decyr-rec->prevdecyr = %lg < %lg : %d\n",recno,rec->decyr-rec->prevdecyr,DECYR_SLOP,rec->decyr-rec->prevdecyr < DECYR_SLOP);
                #endif
                /* Bypass navigation measurements < .06 second since previous */
                while (recno!= 0 && rec->decyr-rec->prevdecyr < DECYR_SLOP) {
                    #ifdef DEBUG
                    fprintf (stderr,"SKIP: recno: %d rec->decyr-rec->prevdecyr = %lg < %lg : %d\n",recno,rec->decyr-rec->prevdecyr,DECYR_SLOP,rec->decyr-rec->prevdecyr < DECYR_SLOP);
                    #endif
                    if (fgets (line,BUFSIZ,file)) {
                        sscanf (line,"%d %d %d %d %lg %d %*s %lf %lf",&rec->yy,&rec->jjj,&rec->hh,&rec->mm,&rec->ss,&xxx,&rec->lat,&rec->lon);
                        rec->ss+=xxx/1000.0;
                        rec->decyr = decyear (&rec->yy,&rec->jjj,&rec->hh,&rec->mm,&rec->ss);
                    } else {
                        break;
                    }
                }
                break;
            case 'd':
                sscanf (line,"%d %d %d %d %lg %d %lf %lf %lf",&rec->yy,&rec->jjj,&rec->hh,&rec->mm,&rec->ss,&xxx,&rec->lat,&rec->lon,&rec->depth);
                rec->ss+=xxx/1000.0;
                if (rec->depth > 99999 || rec->depth < 0) rec->depth = NAN;
                rec->decyr = decyear (&rec->yy,&rec->jjj,&rec->hh,&rec->mm,&rec->ss);
                #ifdef DEBUG
                fprintf (stdout,"PASS: recno: %d rec->decyr-rec->prevdecyr = %lg < %lg : %d\n",recno,rec->decyr-rec->prevdecyr,DECYR_SLOP,rec->decyr-rec->prevdecyr < DECYR_SLOP);
                #endif
                /* Bypass depth measurements < .06 second since previous */
                while (recno!= 0 && rec->decyr-rec->prevdecyr < DECYR_SLOP) {
                    #ifdef DEBUG
                    fprintf (stderr,"SKIP: recno: %d rec->decyr-rec->prevdecyr = %lg < %lg : %d\n",recno,rec->decyr-rec->prevdecyr,DECYR_SLOP,rec->decyr-rec->prevdecyr < DECYR_SLOP);
                    #endif
                    if (fgets (line,BUFSIZ,file)) {
                        sscanf (line,"%d %d %d %d %lg %d %lf %lf %lf",&rec->yy,&rec->jjj,&rec->hh,&rec->mm,&rec->ss,&xxx,&rec->lat,&rec->lon,&rec->depth);
                        rec->ss+=xxx/1000.0;
                        if (rec->depth > 99999 || rec->depth < 0) rec->depth = NAN;
                        rec->decyr = decyear (&rec->yy,&rec->jjj,&rec->hh,&rec->mm,&rec->ss);
                    } else {
                        break;
                    }
                }
                break;
            case 'm':
                sscanf (line,"%d %d %d %d %lg %d %lf %lf %lf %f %lf %f",&rec->yy,&rec->jjj,&rec->hh,&rec->mm,&rec->ss,&xxx,&rec->lat,&rec->lon,&rec->mtf1,&rec->mag,&rec->diur,&rec->msd);
                rec->ss+=xxx/1000.0;
                if (rec->mtf1 < 9999 || rec->mtf1 > 80000) {
                    rec->msd = NAN;
                    rec->mtf1 = NAN;
                    rec->mag = NAN;
                    rec->diur = NAN;
                }
                rec->decyr = decyear (&rec->yy,&rec->jjj,&rec->hh,&rec->mm,&rec->ss);
                #ifdef DEBUG
                fprintf (stdout,"PASS: recno: %d rec->decyr-rec->prevdecyr = %lg < %lg : %d\n",recno,rec->decyr-rec->prevdecyr,DECYR_SLOP,rec->decyr-rec->prevdecyr < DECYR_SLOP);
                #endif
                /* Bypass magnetic measurements < .06 second since previous */
                while (recno!= 0 && rec->decyr-rec->prevdecyr < DECYR_SLOP) {
                    #ifdef DEBUG
                    fprintf (stderr,"SKIP: recno: %d rec->decyr-rec->prevdecyr = %lg < %lg : %d\n",recno,rec->decyr-rec->prevdecyr,DECYR_SLOP,rec->decyr-rec->prevdecyr < DECYR_SLOP);
                    #endif
                    if (fgets (line,BUFSIZ,file)) {
                        sscanf (line,"%d %d %d %d %lg %d %lf %lf %lf %f %lf %f",&rec->yy,&rec->jjj,&rec->hh,&rec->mm,&rec->ss,&xxx,&rec->lat,&rec->lon,&rec->mtf1,&rec->mag,&rec->diur,&rec->msd);
                        rec->ss+=xxx/1000.0;
                        if (rec->mtf1 < 9999 || rec->mtf1 > 80000) {
                            rec->msd = NAN;
                            rec->mtf1 = NAN;
                            rec->mag = NAN;
                            rec->diur = NAN;
                        }
                        rec->decyr = decyear (&rec->yy,&rec->jjj,&rec->hh,&rec->mm,&rec->ss);
                    } else {
                        break;
                    }
                }
                break;
            case 'g':
                sscanf (line,"%d %d %d %d %lg %d %lf %lf %lf %lf %lf",&rec->yy,&rec->jjj,&rec->hh,&rec->mm,&rec->ss,&xxx,&rec->lat,&rec->lon,&rec->gobs,&rec->eot,&rec->faa);
                rec->ss+=xxx/1000.0;
                if (rec->gobs < 970000 || rec->gobs > 990000) {
                    rec->faa = NAN;
                    rec->eot = NAN;
                    rec->gobs = NAN;
                }
                rec->decyr = decyear (&rec->yy,&rec->jjj,&rec->hh,&rec->mm,&rec->ss);
                /* Bypass gravity measurements < .06 second since previous */
                while (recno!= 0 && rec->decyr-rec->prevdecyr < DECYR_SLOP) {
                    if (fgets (line,BUFSIZ,file)) {
                        sscanf (line,"%d %d %d %d %lg %d %lf %lf %lf %lf %lf",&rec->yy,&rec->jjj,&rec->hh,&rec->mm,&rec->ss,&xxx,&rec->lat,&rec->lon,&rec->gobs,&rec->eot,&rec->faa);
                        rec->ss+=xxx/1000.0;
                        if (rec->gobs < 970000 || rec->gobs > 990000) {
                            rec->faa = NAN;
                            rec->eot = NAN;
                            rec->gobs = NAN;
                        }
                        rec->decyr = decyear (&rec->yy,&rec->jjj,&rec->hh,&rec->mm,&rec->ss);
                    } else {
                        break;
                    }
                }
                break;
            default:
                exit (0);
                break;
        }
        return 1;
    } else return 0;
}

double decyear (int *y, int *j, int *h, int *m, double *s)
{
    int leap;
    
    leap = isleapyear (*y);

    return *y + (*j+((*s/60.0+*m)/60.0+*h)/24.0)/(366.0+leap);
}

int ordday2mo (int jjj, int year)
{
    int mo[12]={31,28,31,30,31,30,31,31,30,31,30,31}, ordday=0, i=0;
    
    if (isleapyear (year)) mo[1]++;
    
    while (i < 12 && ordday+mo[i]<jjj) {
        ordday += mo[i];
        i++;
    }
    return i+1;
}

int ordday2dd (int jjj, int year)
{
    int mo[12]={31,28,31,30,31,30,31,31,30,31,30,31}, ordday=0, i=0;
    
    if (isleapyear (year)) mo[1]++;
    
    while (i < 12 && ordday+mo[i]<jjj) {
        ordday += mo[i];
        i++;
    }
    return jjj-ordday;
}

int isleapyear (int year)
{
    return year%400 == 0 || (year%100 != 0 && year%4 == 0);
}

