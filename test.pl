#!/usr/bin/perl

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Data::Dumper;
use Test;
BEGIN { plan tests => 18 };
use XML::IDMEF;

$| = 1;

title("Tested module loadability.");
ok(1); # If we made it this far, the module is loadable.

#my $i = XML::IDMEF::in("");
#print $i->toString;
#exit;


#########################


sub check {
    $error = shift;
    if ($error) {
	print "\nerror: $error\n";
	ok(0);
    } else {
	ok(1);
    }
}

sub title {
    print "=> ".shift(@_)."                  \t";
}



my($idmef, $str_idmef, $idmef2, $type);

#
# dev tests
#

#$idmef = XML::IDMEF::in({}, "idmef.example.2");

my $ST_IDMEF = "<?xml version='1.0' encoding='UTF-8'?>\n<!DOCTYPE IDMEF-Message PUBLIC '-//IETF//DTD RFC XXXX IDMEF v1.0//EN' 'idmef-message.dtd'>\n<IDMEF-Message version='1.0'>\n<Alert ident='abc123456789'>\n<Analyzer analyzerid='bc-fs-sensor13'>\n<Node category='dns'>\n<name>fileserver.example.com</name>\n</Node>\n</Analyzer>\n</Alert>\n</IDMEF-Message>";


##
## test: create new message
##

title "Test creating new idmef message...";
eval {
    $idmef = new XML::IDMEF();

    check("new XML::IDMEF did not return a proper IDMEF message.")
	if ($idmef->out !~ '<\?xml version="1.0" encoding="UTF-8"\?>.*
<!DOCTYPE IDMEF-Message PUBLIC "-//IETF//DTD RFC XXXX IDMEF v1.0//EN" "idmef-message.dtd">.*');
};
check($@);


##
## test parsing idmef string
##

title "Test parsing IDMEF string...";
eval {
    $idmef = new XML::IDMEF();
    $idmef->in($ST_IDMEF);
};
check($@);


##
## test get_type & get_root
##

title "Testing return value of get_root & get_type...";

check("get_root did not return right root name.")
    if ($idmef->get_root ne "IDMEF-Message");

check("get_type did not return right message type.")
    if ($idmef->get_type ne "Alert");

ok(1);


##
## test: contain key
##

title "Testing contains()...";

print "*";
check("contains() says existing node does not exists.")
    if ($idmef->contains("AlertAnalyzerNode") != 1);

print "*";
check("contains() says non-existing node exists.")
    if ($idmef->contains("AlertNode") != 0);

print "*";
check("contains() says existing tag does not exists.")
    if ($idmef->contains("AlertAnalyzeranalyzerid") != 1);

print "* ";
check("contains() says non-existing tag exists.")
    if ($idmef->contains("Alertid") != 0);
    
ok(1);


##
## test: add attributes
##

$idmef = new XML::IDMEF;

title "Test adding attributes to empty message...";
eval {
    $idmef->add("AlertTargetNodecategory", "unknown");
    $idmef->add("AlertSourceNodeAddressident", "45");
    $idmef->add("AlertClassificationorigin", "unknown");

    check("add() did not perform as expected when adding attributes.")
	if ($idmef->out !~ '.*<IDMEF-Message><Alert><Source><Node><Address ident="45"/></Node></Source><Target><Node category="unknown"/></Target><Classification origin="unknown"/></Alert></IDMEF-Message>.*');
};
check($@);


##
## test: add nodes
##

title "Test adding nodes...";
eval {
    $idmef->add("AlertAssessment");
    $idmef->add("AlertTargetFileListFileLinkage");
    $idmef->add("AlertTargetFileListFileLinkage");
    $idmef->add("AlertTargetFileList");

    check("add() did not perform as expected when adding nodes.")
	if ($idmef->out !~ "<Target><FileList/></Target><Target><Node category=\"unknown\"/><FileList><File><Linkage/><Linkage/></File></FileList></Target>");
};
check($@);


##
## test: add content
##

title "Test adding contents...";
eval {
    $idmef->add("AlertAdditionalData","some text");
    $idmef->add("AlertAdditionalDatatype","xml");
    $idmef->add("AlertAdditionalData","some other text");

    check("add() did not perform as expected when adding contents.")
	if ($idmef->out !~ '.*<IDMEF-Message><Alert><Source><Node><Address ident="45"/></Node></Source><Target><FileList/></Target><Target><Node category="unknown"/><FileList><File><Linkage/><Linkage/></File></FileList></Target><Classification origin="unknown"/><Assessment/><AdditionalData>some other text</AdditionalData><AdditionalData type="xml">some text</AdditionalData></Alert></IDMEF-Message>.*');
};
check($@);
    

##
## test: adding id 
##

title "Test create_ident()...";
eval {
    $idmef->create_ident();
};
check($@);


##
## test to_hash
##
 
title("Test to_hash()...");

eval {
    $idmef->to_hash;
};
check($@);


##
## test: create time
##

title "Test create_time()...";
eval {
    $idmef = new XML::IDMEF;

    $idmef->create_time(125500);

    check("create_time() returned a wrong time tag.")
    if ($idmef->out() !~ '.*<IDMEF-Message><Alert><CreateTime ntpstamp="0x83ac68bc.0x0">1970-01-02-T10:51:40Z</CreateTime></Alert></IDMEF-Message>.*');
};
check($@);


##
## test additionaldata
##

title "Test add() with AdditionalData...";

$idmef = new XML::IDMEF;

$idmef->add("AlertAdditionalData", "value0"); 
$idmef->add("AlertAdditionalData", "value1");
$idmef->add("AlertAdditionalDatameaning", "data1");
$idmef->add("AlertAdditionalData", "value2", "data2");   
$idmef->add("AlertAdditionalData", "value3", "data3", "string");

check("add() did not handle AdditionalData properly.")
    if ($idmef->out() !~ '.*<IDMEF-Message><Alert><AdditionalData meaning="data3" type="string">value3</AdditionalData><AdditionalData meaning="data2" type="string">value2</AdditionalData><AdditionalData meaning="data1">value1</AdditionalData><AdditionalData>value0</AdditionalData></Alert></IDMEF-Message>.*');

ok(1);


##
## test set()
##

title "Test set()...";

my $err;

# change existing tag
eval {
    $idmef->set("AlertAdditionalData", "this is a new value changed with set()");
};

if ($@) {
    print "error: set raised exception when it should not while setting tag.\n";
    print "exception: $@\n";
    ok(0);
}

# change existing attribute
eval {
    $idmef->set("AlertAdditionalDatameaning", "this is a new meaning changed with set()");
};

if ($@) {
    print "error: set raised exception when it should not while setting attribute.\n";
    print "exception: $@\n";
    ok(0);
}

# changing non-existing tag
eval {
    $idmef->set("AlertTargetNodeAddressaddress", "blob");
};

check("set: did not raise error when setting non existent content node.\n")
    if (!$@);

# changing non content node
eval {
    $idmef->set("Alert", "blob");
};

check("set: did not raise error when setting node that does not accept content.\n")
    if (!$@);

ok(1);


##
## test get()
##

my $v;

# get existing content
title "Test get() on existing content...";
eval {
    $v =  $idmef->get("AlertAdditionalData");
};
check($@);

check("get: returned wrong content when getting content.\n")
    if ($v ne "this is a new value changed with set()");

# get existing attribute
title "Test get() on existing attribute...";
eval {
    $v =  $idmef->get("AlertAdditionalDatameaning");
};
check($@);

check("get: returned wrong content when getting attribute.\n")
    if ($v ne "this is a new meaning changed with set()");

# get non existing content
title "Test get() on non-existing content...";
eval {
    $v =  $idmef->get("AlertTargetNodeAddressaddress");
};
check($@);

check("get: returned wrong content when getting non existent content.\n")
    if (defined($v));


##
## test encoding of special characters
##

title("Test encoding of special characters...");

my $string1 = "hi bob&\"&amp;&#x0065";

$idmef = new XML::IDMEF;

$idmef->add("AlertAdditionalData", "$string1");

check("add() did not handle special characters encoding according to XML specs.")
    if ($idmef->out() !~ '.*<IDMEF-Message><Alert><AdditionalData>hi bob&amp;&quot;&amp;amp;&amp;#x0065</AdditionalData></Alert></IDMEF-Message>.*');

ok(1);


##
## test adding 2 similar nodes
##

title("Testing multiple add() calls bug...");

$idmef = new XML::IDMEF;

$idmef->add("AlertAnalyzerNodeAddresscategory", "ipv4-addr");
$idmef->add("AlertAnalyzerNodeAddressaddress",  "1.1.1.1");

$idmef->add("AlertAnalyzerNodeAddresscategory", "ipv4-addr");
$idmef->add("AlertAnalyzerNodeAddressaddress",  "2.2.2.2");

check("add() call bug still here!")
    if ($idmef->out() !~ '<IDMEF-Message><Alert><Analyzer><Node><Address category="ipv4-addr"><address>2.2.2.2</address></Address><Address category="ipv4-addr"><address>1.1.1.1</address></Address></Node></Analyzer></Alert></IDMEF-Message>');

ok(1);

#$idmef = $idmef->in("idmef.example.1");
#print Dumper($idmef->to_hash);


