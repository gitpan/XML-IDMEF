# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test;
BEGIN { plan tests => 6 };
use XML::IDMEF;

ok(1); # If we made it this far, we're ok.

#########################


sub check {
    $error = shift;
    if ($error) {
	print "error: $error\n";
	ok(0);
    } else {
	ok(1);
    }
}



my($idmef, $str_idmef, $idmef2, $type);

##
## test 1: create simple IDMEF message object
##

eval {
    print "  Trying to build a simple IDMEF message...\n";
    
    $idmef = new XML::IDMEF();  
    
    $idmef->create_ident();
    $idmef->create_time();

    $idmef->add("AlertTargetNodename", "mynode");
    $idmef->add("AlertAdditionalData", "value1", "data1"); 
    $idmef->add("AlertAdditionalData", "value2", "data2");
    $idmef->add("AlertAnalyzermodel", "myids");
    
    $str_idmef =  $idmef->out();
};

check($@);


##
## test 2: read in the IDMEF string
##

eval {
    print "  Parsing an IDMEF message from a string...\n";
    $idmef2 = (new XML::IDMEF)->in($str_idmef);    
};

check($@);


##
## test 3: getting type of inslurped idmef
##

print "  Checking type of parsed IDMEF...\n";
$type = $idmef2->get_type();
if ($type eq "Alert") {
    ok(1);
} else {
    print "error: get_type returned wrong value ($type)\n";
    ok(0);
}


##
## test 4: testing at_least_one
##

my($test1, $test2, $test3);
print "  Testing at_least_one...\n";

print "  Checking valid path\n";
ok($idmef->at_least_one("AlertTargetNodename"));

print "  Checking unset valid path\n";
ok(!$idmef->at_least_one("AlertSourceNodename"));

print "  Checking not valid path\n";
ok(!$idmef->at_least_one("AlertTargetNodeinterface"));






