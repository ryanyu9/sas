/*
Author: Ryan Yu
Purpose: Reduce the length of character variables to maximum length of real values in each dataset;
*/

libname original '...';
libname reduced '...';

* need to change the value for the following two macro variables;
%let orig_loc=original;
%let redu_loc=reduced;

options varlenchk=nowarn;

*get all data/variables information;
proc contents noprint data=&orig_loc.._all_ out=domain0;run;

data domain;
	set domain0;
	if type=2;
run;

data _null_;
	set domain end=eof;
	call symput('domain'||trim(left(trim(put(_n_,4.)))),trim(Memname));
	call symput('name'||trim(left(trim(put(_n_,4.)))),trim(Name));
	if eof then call symput('varno',trim(left(trim(put(_n_,4.)))));
run;

*get max length of each character variable based on current data;
%macro getmaxlen();
%do i=1 %to &varno.;
	data varlen;
		set &orig_loc..&&domain&i..;
		len=length(&&name&i..);
	run;
	proc sql;
		create table len as
		select "&&domain&i.." as memname, "&&name&i.." as name, max(len) as maxlen
		from varlen;
	quit;
	data domain;
		merge domain
			len;
		by memname name;
	run;
%end;
%mend getmaxlen;

%getmaxlen();

*identify which datasets need variable length correction;
data domain1;
	set domain;
	if maxlen^=. and maxlen<LENGTH;
	fmt=strip(name)||" $"||strip(put(maxlen,best.))||".";
run;

proc sql;
	create table memname as
	select distinct memname, MEMLABEL
	from domain1;
quit;

data _null_;
	set memname end=eof;
  call symput('mem'||trim(left(trim(put(_n_,2.)))),trim(Memname));
	call symput('memlbl'||trim(left(trim(put(_n_,2.)))),trim(MEMLABEL));
  if eof then call symput('memno',trim(left(trim(put(_n_,2.)))));
run;

proc sql noprint;
	select strip(memname)  into: dschg separated by " "
	from memname ;
quit;

%macro correctlen();
%do i=1 %to &memno.;
	*identify which variables need length update;
	proc sql noprint;
		select strip(fmt)  into: fmt separated by " "
		from domain1 where memname="&&mem&i..";
	quit;

	data Rdata;
		length &fmt.;
		set &orig_loc..&&mem&i..;
	run;

	*order the columns same as original data;
	proc sql noprint;
		select name into: names separated by ' '
		from domain0
		where memname="&&mem&i.."
		order by varnum;
	quit;

	data &redu_loc..&&mem&i..(label="&&memlbl&i..");
		retain &names.;
		set Rdata;
		keep &names.;
	run;
%end;
%mend correctlen;

%correctlen;

*copy over the data that do not need update;
proc copy in=&orig_loc. out=&redu_loc. memtype=data;
	exclude &dschg.;
run;
