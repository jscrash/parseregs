#!/usr/bin/awk -f
# 
# Create an xml document from the regulations pdf.  
# You should feed this program the output of the following command:
#      java -jar tika-app-1.1.jar  -t http://gaming.nv.gov/modules/showdocument.aspx?documentid=2957
# 
# Julian Carlisle 	June 25, 2012 
#
###################################################################################################

#
BEGIN 	{

START_CDAT=		"<![CDATA[";			# encapsulate and protect text oddities.
END_CDAT=		"]]>";
START_DESC=		"<description>";
END_DESC=		"</description>";
START_REGS=		"<regs>";
END_REGS=		"</regs>";
START_SECTION=		"<section>";
END_SECTION=		"</section>";
START_TEXT=		"<text>";
END_TEXT=		"</text>";
START_REG=		"<regulation>";
END_REG=		"</regulation>";
START_TITLE=		"<title>";
END_TITLE=		"</title>";

#
# The regs doc uses digraph encoded bytes for several special characters so form a header with a
# spec for an encoding that supports them.  This eliminates the perl pre-processor step and allows
# all our parsing to be done in this program alone.  The digraphs now move downstream into the xml
# which is important since a number of them represent quoting chars.
#
print "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?><!DOCTYPE regs [\n\
<!ELEMENT description (#PCDATA)>\n\
<!ELEMENT title (#PCDATA)>\n\
<!ELEMENT text (#PCDATA)>\n\
<!ELEMENT section (title|text)*>\n\
<!ELEMENT regulation (description|section)*>\n\
<!ELEMENT regs (regulation)+>\n\
]>\n" START_REGS;
# Join lines
RS="\n\n?"
}

# Put all special cases here at the top.  I might contact the NV folks to ask for these corrections to be 
# made in the source doc since they are after all errors.

# document inconsistancy: section 11.010 is implemented without the subsection leading zero 
$0 ~ /^[ \t]*11\.10/ 	{ if (start) $1="11.010"; } 

# regulation 13 doesn't fit our patterns because it is empty
$0 ~ /Repealed 3.22.07/ { 
	if (indescription && start)  {
		print END_CDAT END_DESC;
		indescription=0;
	}
	next;
}

# Join lines where tika has produced an extra blank
$0 ~ /^$/ {next}
NF==0 {next}

# toss these end of reg section markers for now but on the next version where I will parse 
# the STANDARDs that are defined in some of the regs, this will be an important marker for 
# the recognition that we are still in a reg but emitting STANDARDs records as an xml record
# within the REGULATION section.
$0 ~ /^Regulation .*/ {next}
$0 ~ /^Technical Standards/ {next}
$0 ~ /^End.*Technical Standards.*/ {next}

$0 ~ /[ \t]*(Rev.[ \t]*[0-9]?[0-9]?\/[0-9][0-9]?)/ {next}
$1 ~ /^REGULATION/	{ 


	curreg=$2;
	if (!( curreg in regs)) {			# every regulation is seen first in the contents so remember them 
		regs[curreg] = 1;
		start=0;
		next;
	}
	else { 					# we only start parsing and emitting the second encounter of each.
		start=1; 
		if (intext) {
			print END_CDAT END_TEXT END_SECTION ;
			intext=0;
		}
		if (curreg != 1) 
			print END_REG;		

		print START_REG curreg;
		first=1;

		print  START_DESC START_CDAT ;     # in CDATA encapsulation so that jira will accept the digraphs.
		indescription=1;
		next;

	}
}
$0 ~ /^[A-Z \t,-]*$/ {if (!indescription) next}
$0 ~ /^[ \t]*16\.010.14.\./ {print $0; next} 
$0 ~ /16.200 if/ { print $0; next}
$0 ~ /16.250 through/ { print $0; next}
$0 ~ /16.250 and/ { print $0; next}
$1 ~ /^[ \t]*[1-9][0-9]?[A-Z]?\.[0-9][0-9][0-9]*[^(]*.*[^,\.;:]$/ 	{ 
# every section is seen first in the header within each regulation so remember them 
# because we only start parsing and emitting the second encounter of each.
	if (start) {
		if (!($1 in sections)) {
			S=substr($0,length($1)+1, length($0));
			gsub(/^[ \t]*/,"",S);
			sections[$1]=S;
			skip=1;
			next;
		} 
		else 
			skip=0;

		if (!first) 
			print END_CDAT END_TEXT END_SECTION "\n";
		else {
			print END_CDAT END_DESC "\n";
			indescription=0;
		}
		print START_SECTION $1 \
			START_TITLE sections[$1] END_TITLE \
			START_TEXT START_CDAT;

		
		intext=1;
		first=0;

# emit without the section title.  This only matters on the first line.
		S=substr($0,index($0,$2),999);
		printf ("%s",substr(S,index(S,".")+1,999));
		next;
		 
	}
	first=0;
}

# emit selectively by default.  Note this is exclusively outputting text bodies or
# description bodies since all tags or special cases are emitted above.
{ 
	if (start && !skip) {
#		gsub(/ \([a-z]\)/,"\n  &");	
#		gsub(/ \([0-9]\)/,"\n &");
		print $0;
	}
}

END {print END_CDAT END_TEXT END_SECTION END_REG END_REGS }

#{
#    "fields": {
#       "project":
#       {
#          "key": "TEST"
#       },
#       "summary": "REST ye merry gentlemen.",
#       "description": "Creating of an issue using project keys and issue type names using the REST API",
#       "issuetype": {
#          "name": "Bug"
#       }
#   }
#}
