# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test;
BEGIN { plan tests => 1 };
use XML::IDMEF;

ok(1); # If we made it this far, we're ok.

#########################

eval {
    print "Trying to build a simple IDMEF message:\n";
    
    my $idmef = new IDMEF();  
    
    $idmef->create_ident();
    $idmef->create_time();

    $idmef->add("AlertTargetNodename", "mynode");
    $idmef->add("AlertAdditionalData", "value1", "data1"); 
    $idmef->add("AlertAdditionalData", "value2", "data2");
    $idmef->add("AlertAnalyzermodel", "myids");
    
    print $idmef->out();
};

if ($@) {
    print "error: $@";
    ok(0);
} else {
    ok(1);
}

