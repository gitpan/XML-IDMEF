# $Id: Simple.pm,v 1.1.1.1.2.2 2002/02/09 22:13:34 grantm Exp $

package XML::IDMEF;

# syntax cerbere
use 5.006;
use strict;
use warnings;

# various includes
use Carp;
use XML::Simple;
#use Data::Dumper;

# export, version, inheritance
require Exporter;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = ( 'all' => [ qw() ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(xml_encode
		 xml_decode
		 byte_to_string
		 extend_idmef	
		 );

our $VERSION = '0.04';



##----------------------------------------------------------------------------------------
##
## IDMEF - An XML wrapper for building/parsing IDMEF messages
##
## Erwan Lemonnier - Proact Defcom - 2002/05
##
## DESC:
##
##    IDMEF.pm is an interface for simply creating and parsing IDMEF messages.
##    It is compliant with IDMEF v0.5, and hence provides calls for building Alert,
##    ToolAlert, CorrelationAlert, OverflowAlert and Heartbeat IDMEF messages.
##
##    This interface has been designed for simplifying the task of translating a
##    key-value based format to its idmef representation. A typical session involves
##    the creation of a new IDMEF message, the initialisation of some of it's fields
##    and its conversion into an IDMEF string, as illustrated below:
##
##        use XML::IDMEF;
##
##        my $idmef = new XML::IDMEF();
##        $idmef->create_ident();
##        $idmef->create_time();
##        $idmef->add("AlertAdditionalData", "myvalue", "mymeaning"); 
##        $idmef->add("AlertAdditionalData", byte_to_string($bytes), "binary-data", "byte");
##        $idmef->add("AlertAnalyzermodel", "myids");
##        print $idmef->out();
##
##    An interface to load and parse an IDMEF message is also provided (with the
##    'to_hash' function), but is quite limited.
##
##    This module contains a generic XML DTD parser and include a class based definition
##    of the IDMEF DTD. It can hence easily be upgraded or extended to support new XML
##    node. For information on how to extend IDMEF with IDMEF.pm, read the documentation
##    in the source code.
## 
##
## REM: to extract the api documentation, do 'cat IDMEF.pm | grep "##" | sed -e "s/##//"'
##
##
## BSD LICENSE:
## Copyright (c) 2002, Proact Defcom
##         All rights reserved.
##
##         Redistribution and use in source and binary forms, with or without modification, are permitted
##         provided that the following conditions are met:
##
##              Redistributions of source code must retain the above coopyright notice, this list 
##              of conditions and the following disclaimer. 
##              Redistributions in binary form must reproduce the above copyright notice, this list of
##              conditions and the following disclaimer in the documentation and/or other materials
##              provided with the distribution. 
##              Neither the name of the <ORGANIZATION> nor the names of its contributors may be used
##              to endorse or promote products derived from this software without specific prior written
##              permission. 
##
##         THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
##         AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
##         IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
##         ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
##         LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
##         CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
##         SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
##         INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
##         CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
##         ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
##         POSSIBILITY OF SUCH DAMAGE.
##
##----------------------------------------------------------------------------------------
##
## LIST OF FUNCTIONS
##
##    new             # create new IDMEF message
##    in              # load new IDMEF message from string/file
##    out             # write IDMEF message to string/file
##
##    to_hash         # convert IDMEF message to hash for easy parsing
##    add             # add a field to IDMEF message
##    get_type        # return type of IDMEF message
##
##    create_ident    # initialyze the Alertident field witha unique id string
##    create_time     # initialize the CreateTime field with the current time
##
## EXPORTS:
##
##    xml_encode      # encode data (not binary) into an IDMEF compliant string
##    xml_decode      # and the other way round
##    byte_to_string  # encode binary data into an IDMEF compliant string
##
##
##



# empty idmef template
use constant EMPTYIDMEF  => "<IDMEF-Message version=\"0.5\"></IDMEF-Message>";



#
# IDMEF DTD REPRESENTATION
# ------------------------
#
# The IDMEF DTD, as all DTDs, can be represented as a class hierarchy in which
# each class corresponds to one node level. There can be 2 kind of relations between
# these node classes: inheritance (ex: a ToolAlert is an Alert) and composition
# (Alert contains Analyzer, Source, Target...).
# 
# Below is a hash structure, called 'IDMEF_DTD', which defines the whole IDMEF DTD
# as in version 0.5. Each key is the name of the root tag of an IDMEF node, and its
# value is a structure representing the attributes, tags and subnodes allowed for
# this node, as well as the node's subclasses if there are some. If on attribute can
# take only a limited set of values, this is also specified. One class element (tag,
# attribute or node) may appear more than once, in which case it is specified.
#
# This IDMEF DTD is then parsed by the 'load_xml_dtd' function when the IDMEF.pm
# module is loaded, which in turn builds two internal and more convenient 
# representations: $EXPAND_PATH & $CHECK_VALUE. These 2 hashes are used by the add()
# call, and faster to use than the DTD class construction.
#
# The main advantage of prefering a DTD representation of IDMEF is its flexibility:
# if the IDMEF rfc happens to change, the DTD hash is the only part of this module
# which will need an upgrade. Beside, it gets easy to extend IDMEF by adding to the
# DTD some home-defined root class, and extend IDMEF.pm. The extension module only
# needs to contain a DTD hash extending the one of IDMEF, and call 'extend_idmef'.
# All other functions ('in', 'out', 'add', 'to_hash'...) are then inherited from IDMEF.
#
# This code is actually build in a very generic way and could be used with whatever 
# other XML format.
#
# DTD hash:
# ---------
#
# A DTD is represented as a hash where ech key is the name of a node, and each value
# a hash encoding the corresponding 'class' definition of this node.
# A 'class' is a generic template describing one IDMEF node.
# A node has a name, which is its tag string. This name is the node's key in the DTD
# hash.
# A node may have subnodes. These subnodes are listed in an anonymous array associated
# with the 'SUBCLASS' key of the class hash. 
# A node may contain nested tags, listed in the array associated to the 'TAGS' key.
# Some nodes may accept a content without nested tags (ex: AdditionalData has
# a content value without surrounding tags. CreateTime as well). To represent this
# special case of tag content, add the keyword 'CONTENTKEY' to the TAGS array.
# A node can also have attributes, which are represented as keys of ATTRIBUTES
# hash. The value associated with each key is an array of the values allowed for this
# attributes, or an empty array if there are no restrictions on the value.
# Finally, some of the node's components (attribute, tag or subnode) may occur more
# than once. These particular components are listed in the array associated with the
# key 'MULTI'.
#
# ex: DTD key-value pair
#
# "Classname" = {
#            SUBCLASS    => [ "subClass1", "subClass2"... ],
#            TAGS        => [ CONTENTKEY, "tag1",... ], 
#            NODES       => [ "Class1", "Class2",... ],
#            ATTRIBUTES  => { "attribute1" => [ list of values ],
#                             "attribute2" => [],
#                             ...
#                           },
#            MULTI       => ["Class2", "attribute1",...],
#          }
#


#
# CONTENTKEY:
# -----------
#
# content key keyword. special tag key meaning that the associated value
# is a tag content without surrounding simple tags (tags without attribute)
# cf CreateTime & AdditionalData. Don't choose an idmef official tagname, otherwise conflict

use constant CONTENTKEY => "PerlIDMEFContent";


#
# IDMEF_DTD:
# ----------
#
# A hash encoding the whole IDMEF DTD as of version 0.5
# It contains definitions for all the xml classes necessary to build
# the root IDMEF messages of type Alert and Heartbeat, as well as their
# subclasses.

my $IDMEF_DTD = {

    "Heartbeat" => {
	ATTRIBUTES  => { "ident" => [] },
	NODES       => [ "Analyzer", "CreateTime", "AnalyzerTime", "AdditionalData" ],
	MULTI       => [ "AdditionalData" ],
    },

    "Alert" => {
	SUBCLASS    => [ "ToolAlert", "CorrelationAlert", "OverflowAlert" ],
	ATTRIBUTES  => { "ident"  => [], "impact" => [], "action" => [] },
	NODES       => [ "Analyzer", "CreateTime", "DetectTime", "AnalyzerTime",
			 "Source", "Target", "Classification", "Assessment", 
			 "AdditionalData" ],
	MULTI       => [ "Source", "Target", "AdditionalData" ],
    },

    "ToolAlert"  => { 
	NODES       => [ "alertident" ],
	TAGS        => [ "name", "command" ], 
	MULTI       => [ "alertident" ],
    },

    "CorrelationAlert" => {
	NODES       => [ "alertident" ],
	TAGS        => [ "name" ],
	MULTI       => [ "alertident" ],
    },

    "OverflowAlert" => {
	TAGS        => [ "program", "size", "buffer" ],
    },

    "alertident" => {
	ATTRIBUTES  => { "analyzerid" => [] },
	TAGS        => [ CONTENTKEY ],
    },

    "Analyzer" => {
        ATTRIBUTES  => { "analyzerid"   => [], "manufacturer" => [], "model"        => [],
			 "version"      => [], "class"        => [], "ostype"       => [],
			 "osversion"    => [], 
		     },
	NODES       => [ "Node", "Process" ],
    },


    "Classification" => {
	ATTRIBUTES  => { "origin" => ["unknown", "bugtraqid", "cve", "vendor-specific"] },
	TAGS        => [ "name", "url" ],
    },
    
    "Source" => {
	ATTRIBUTES  => { "ident"      => [], "interfaces" => [], "spoofed"    => ["unknown", "yes", "no"] },
	NODES       => [ "Node", "User", "Process", "Service" ],
    },
    
    "Target" => {
	ATTRIBUTES  => { "ident" => [], "decoy" => ["unknown","yes","no"], "interfaces" => [] },
	NODES       => [ "Node", "User", "Process", "Service", "FileList" ],
    },
    
    "Assessment" => {
	NODES       => [ "Impact", "Action", "Confidence" ],
	MULTI       => [ "Action" ],
    },
    
    "Impact" => {
	ATTRIBUTES  => { "severity"   => ["low", "medium", "high"],
			 "completion" => ["failed", "succeeded"],
			 "type"       => ["admin", "dos", "file", "recon", "user", "other"],
		     },
	TAGS        => [ CONTENTKEY ],
    },
    
    "Action" => {
	ATTRIBUTES  => { "category" => ["block-installed", "notification-sent", "taken-offline"] },
	TAGS        => [ CONTENTKEY ],
    },
    
    "Confidence" => {
	ATTRIBUTES  => { "rating" => ["low", "medium", "high", "numeric"] },
	TAGS        => [ CONTENTKEY ],
    }, 
    
    "AdditionalData" => {
	ATTRIBUTES  => { "type" => ["string", "boolean", "byte", "character", "date-time", "integer",
				    "ntpstamp", "portlist", "real", "xml"],
			 "meaning" => [],
		     },
	TAGS        => [ CONTENTKEY ],
    }, 
    
    "CreateTime" => {
	ATTRIBUTES  => { "ntpstamp" => [] },
	TAGS        => [ CONTENTKEY ],
    },
    
    "DetectTime" => {
	ATTRIBUTES  => { "ntpstamp" => [] },
	TAGS        => [ CONTENTKEY ],
    },
    
    "AnalyzerTime" => {
	ATTRIBUTES  => { "ntpstamp" => [] },
	TAGS        => [ CONTENTKEY ],
    },
    
    "Node" => {
	ATTRIBUTES  => { "category" => [ "unknown", "ads", "afs", "coda", "dfs", "dns", "kerberos", "nds",
					 "nis", "nisplus", "nt", "wfw"],
			 "ident"    => [],
		     },
	TAGS        => [ "location", "name" ],
	NODES       => [ "Address" ],
	MULTI       => [ "Address" ],
    },
    
    "Address" => {
	ATTRIBUTES  => { "ident"     => [], "vlan-num"  => [], "vlan-name" => [],
			 "category"  => [ "unknown", "atm", "e-mail", "lotus-notes", "mac", "sna",
					  "vm", "ipv4-addr", "ipv4-addr-hex", "ipv4-net", "ipv4-net-mask",
					  "ipv6-addr", "ipv6-addr-hex", "ipv6-net", "ipv6-net-mask" ],
		     },
	TAGS        => [ "address", "netmask" ],
    },
    
    "User" => {
	ATTRIBUTES  => { "ident"    => [], "category" => ["unknown", "application", "os-device"] },
	NODES       => [ "UserId" ],
	MULTI       => [ "UserId" ],
    },
    
    "UserId" => {
	ATTRIBUTES  => { "ident" => [],
			 "type"  => [ "current-user", "original-user", "target-user", "user-privs",
				      "current-group", "group-privs" ],
		     },
	TAGS        => [ "name", "number" ],
    },
    
    "Process" => {
	ATTRIBUTES  => { "ident" => [] },
	TAGS        => [ "name", "pid", "path", "arg", "env" ],
	MULTI       => [ "arg", "env" ],
    },

    "Service" => {
	SUBCLASS    => [ "WebService", "SNMPService" ],
	ATTRIBUTES  => { "ident" => [] },
	TAGS        => [ "name", "port", "portlist", "protocol" ],
    },
    
    "WebService" => {
	TAGS        => [ "url", "cgi", "http-method", "arg" ],
	MULTI       => [ "arg" ],
    },
    
    "SNMPService" => {
	TAGS        => [ "oid", "community", "command" ],
    },
    
    "FileList" => {
	NODES       => [ "File" ],
	MULTI       => [ "File" ],
    },
    
    "File" => {
	ATTRIBUTES  => { "ident"    => [], "category" => ["current","original"], "fstype"   => [] },
	TAGS        => [ "name", "path", "create-time", "modify-time", "access-time", "data-size",
			 "disk-size" ],
	NODES       => [ "FileAccess", "Linkage", "Inode" ],
	MULTI       => [ "FileAccess", "Linkage" ],
    },
    
    "FileAccess" => {
	TAGS        => [ "permission" ],
	NODES       => [ "UserId" ],
    },
    
    "Linkage" => {
	ATTRIBUTES  => { "category" => ["hard-link", "mount-point", "reparse-point", "shortcut", 
					"stream", "symbolic-link"] },
	TAGS        => [ "name", "path" ], 
	# ignore File node: the DTD parser does not support recursive nodes
    },
    
    "Inode" => { 
	TAGS        => ["change-time", "number", "major-device", "minor-device", "c-major-device",
			"c-minor-device"],
    },
};


#
# INTERNAL IDMEF STRUCTURES
#

# $EXPAND_PATH is a hash table linking an idmef tag path to the corresponding list
# of arguments needed to add a value at this path with add_in_simplehash.
# each key is a tagpath to a given IDMEF field, as given to the 'add()' call.
# each corresponding value is an array containing the list of tags in the
# tagpath, preceded by 2 integers. The first one is 'A' if the pointed field is
# an attribute, 'T' if it is a tag, 'N' if it is a node. The second one is always
# set to 0. It is the index of the currently examined field in the tag path
# used internally by add_in_simplehash.
# ex:
#    'AlertTargetUserUserIdident'  => [ A, 0, "Alert", "Target", "User", "UserId", "ident"],
#    'AlertTargetUserUserIdtype'   => [ A, 0, "Alert", "Target", "User", "UserId", "type"],
#    'AlertTargetUserUserIdname'   => [ T, 0, "Alert", "Target", "User", "UserId", "name"],
#    'AlertTargetUserUserIdnumber' => [ T, 0, "Alert", "Target", "User", "UserId", "number"],
#    'AlertTargetUserUserId'       => [ N, 0, "Alert", "Target", "User", "UserId"],

my $EXPAND_PATH = {};


# hash of the tagpaths for which the values can only take a limited set of values
# which can be checked with check_allowed. each key is a tagpath, each value is
# an array of the corresponding allowed values.
#
# ex: 
#    'OverflowAlertAssessmentImpactcompletion' => [ 'failed', 'succeeded' ],
#

my $CHECK_VALUE = {};


# a counter used by create_ident's unique id generator
#

my $idnum = 0;






##================================================================================
##
## XML CLASS LOADER
##
##================================================================================
##
##  Below is the generic code for loading a class based representation of an XML
##  DTD into structures optimised for internal usage (EXPAN_PATH & CHECK_VALUE)
##


# extend_subclass(<class>, <subclass>)
#   take a class and its subclass and add to the subclass all
#   the nodes, tags and attributes of the mother class.
#   used by load_xml_dtd()
#

sub extend_subclass {
    my ($class, $subclass) = @_;

    $subclass->{TAGS} = [] if (!exists($subclass->{TAGS}));
    $subclass->{TAGS} = [@{$subclass->{TAGS}}, @{$class->{TAGS}}] if (exists($class->{TAGS}));

    $subclass->{NODES} = [] if (!exists($subclass->{NODES}));
    $subclass->{NODES} = [@{$subclass->{NODES}}, @{$class->{NODES}}] if (exists($class->{NODES}));    

    $subclass->{MULTI} = [] if (!exists($subclass->{MULTI}));
    $subclass->{MULTI} = [@{$subclass->{MULTI}}, @{$class->{MULTI}}] if (exists($class->{MULTI}));

    $subclass->{ATTRIBUTES} = {} if (!exists($subclass->{ATTRIBUTES}));
    if (exists($class->{ATTRIBUTES})) {
	foreach my $k (keys(%{$class->{ATTRIBUTES}})) {
	    $subclass->{ATTRIBUTES}->{$k} = $class->{ATTRIBUTES}->{$k};
	}
    }
}



#----------------------------------------------------------------------------------------
#
# load_xml_dtd(<DTD>, <ROOT_CLASS>, ...)
#
# ARGS:
#   <DTD>         a DTD hash
#   <ROOT_CLASS>  the name (string) of the DTD's root class
#
# RETURN:
#  This is the DTD parser used to load the IDMEF DTD in the DTD
#  engine at startup.
#  This function parses the DTD class hierarchy as defined
#  through the <DTD> hash and build the xml class tree of
#  the root node <ROOT_CLASS>. 
#  It simultaneously fill the EXPAND_PATH and CHECK_VALUE 
#  hashes used by 'add()' calls.
#
# EX:
#    # load the IDMEF DTD at startup
#    load_xml_dtd($IDMEF_DTD, "Alert");
#    load_xml_dtd($IDMEF_DTD, "Heartbeat");
#

sub load_xml_dtd {
    my ($dtd, $node, $nodename, @path, $attrib, $v, $k, $key, $attname, @list, $size_list, $n, $tag, $class);
    ($dtd, $nodename, @path) = @_;
    
    push @path, $nodename;
    $node = $dtd->{$nodename};

    # add attributes to EXPAND_PATH & CHECK_VALUE    
    if (exists($node->{ATTRIBUTES})) {
	$attrib = $node->{ATTRIBUTES};

	foreach $attname ( keys(%{$attrib}) ) {
	    $k = join '', @path, $attname;
	    $v = [ 'A', 0, @path, $attname ];
	    $EXPAND_PATH->{$k} = $v;
	    
	    @list = @{$attrib->{$attname}};
	    $size_list = @list;
	    $CHECK_VALUE->{$k} = [ @list ] if ($size_list > 0);
	}
    }

    # add tags to EXPAND_PATH & CHECK_VALUE    
    if (exists($node->{TAGS})) {
	foreach $tag (@{$node->{TAGS}}) {
	    $k = join '', @path;
	    $k = $k.$tag if ($tag ne CONTENTKEY);
	    $v = [ 'T', 0, @path, $tag ];
	    $EXPAND_PATH->{$k} = $v;
	}
    }
    # rem: contentkey should overwrite the path tag of its father node

    # call class parser recursively on each node
    if (exists($node->{NODES})) {
	foreach $key (@{$node->{NODES}}) {
	    die "IDMEF.pm - Class loader: $k in node $nodename is not a known class.\n" 
		if (!exists($dtd->{$key}));
	    $k = join '', @path, $key;
	    $EXPAND_PATH->{$k} = [ 'N', 0, @path, $key ];
	    load_xml_dtd($dtd, $key, @path);
	}
    }

    # now take care of subclasses...
    if (exists($node->{SUBCLASS})) {
	pop @path;
	foreach $key (@{$node->{SUBCLASS}}) {
	    die "IDMEF.pm - Class loader: subclass $k in node $node->{CLASSNAME} is not a known class.\n" 
		if (!exists($dtd->{$key}));
	    extend_subclass($node, $dtd->{$key});
	    $k = join '', @path, $key;
	    $EXPAND_PATH->{$k} = [ 'N', 0, @path, $key ];
	    load_xml_dtd($dtd, $key, @path);
	}
    }
}



##----------------------------------------------------------------------------------------
##
## extend_idmef($DTD_extension, "new_root_class")
##
## ARGS:
##   $DTD_extension    a DTD hash, as described in the source doc above.
##   "new_root_class"  the name of a new root class
##
## RETURN:
##  This function can be used to extend IDMEF by adding a new
##  root class definition to the original IDMEF DTD.
##  $DTD_extension is a DTD hash, as defined above, providing definitions
##  for all the new IDMEF classes introduced by the extension, including
##  the one for the new root class.
##  "new_root_class" is the name of the root node of the IDMEF extension.
##  From now on, the usual IDMEF calls ('in', 'add', 'to_hash'...) can be
##  used to create/parse extended messages as well. 
##

sub extend_idmef {
    my($dtd, $name) = @_;
    
    foreach my $k (keys(%{$dtd})) {
	$IDMEF_DTD->{$k} = $dtd->{$k};
    }

    load_xml_dtd($IDMEF_DTD, $name);
}


##--------------------------------------------------------------------------------
##
## MODULE LOAD TIME INITIALISATION
##
##--------------------------------------------------------------------------------

# DTD engine initialization:
#    load the IDMEF root classes: Alert & Heartbeat, and build the intermediary 
#    structures representing the DTD (EXPAND_PATH & CHECK_VALUE) used by API calls
#    such as add(). 
load_xml_dtd($IDMEF_DTD, "Alert");
load_xml_dtd($IDMEF_DTD, "Heartbeat");

# return true to package loader
1;












##=========================================================================================
##
##  MODULE FUNCTIONS 
##
##=========================================================================================
##
##
## EXPORTED FUNCTIONS:
## -------------------
##



##----------------------------------------------------------------------------------------
##
## <byte_string> = byte_to_string(<bytes>)
##
## ARGS:
##   <bytes>    a binary string
##
## RETURN:
##   <byte_string>: the string obtained by converting <bytes> into its IDMEF representation,
##   refered to as type BYTE[] in the IDMEF rfc.
##

sub byte_to_string {
    return join '', map( { "&\#$_;" } unpack("C*", $_[0]) ); 
}



##----------------------------------------------------------------------------------------
##
## <xmlstring> = xml_encode(<string>)
##
## ARGS:
##   <string>   a usual string
##
## RETURN:
##   <xmlstring>: the xml encoded string equivalent to <string>. 
##
## DESC:
##   You don't need this function if you are using add() calls (which already calls it).
##   To convert a string into an idmef STRING, xml_encode basically replaces
##   characters:         with:
##         &                 &amp;
##         <                 &lt;
##         >                 &gt;
##         "                 &quot;
##         '                 &apos;
##   REM: if you want to convert data to the BYTE[] format, use 'byte_to_string' instead
##

sub xml_encode {
    my ($st) = @_;

    if (defined $st) {
	
	# escape &#(.*); codes
	$st =~ s/&\#x(.{4});/\#\#x$1;/g;
	$st =~ s/&\#(.{2,3});/\#\#$1;/g;
	
	$st =~ s/&\#(.*);//g;
	$st =~ s/&/&amp\;/g;
	$st =~ s/</&lt\;/g;
	$st =~ s/>/&gt\;/g;
	$st =~ s/\"/&quot\;/g;
	$st =~ s/\'/&apos\;/g;
	
	# replace back bin codes
	$st =~ s/\#\#x(.{4});/&\#x$1;/g;
	$st =~ s/\#\#(.{2,3});/&\#$1;/g;
    }

    return $st;
}



##----------------------------------------------------------------------------------------
##
## <string> = xml_decode(<xmlstring>)
##
## ARGS:
##   <xmlstring>  a xml encoded IDMEF STRING
##
## RETURN:
##   <string>     the corresponding decoded string
##
## DESC:
##   You don't need this function with 'to_hash' (which already calls it).
##   It decodes <xmlstring> into a string, ie replace the following
##   characters:         with:
##         &amp;              &
##         &lt;               <
##         &gt;               >
##         &quot              "
##         &apos              '
##         &#xx;              xx in base 10
##         &#xxxx;            xxxx in base 16
##   It also decodes strings encoded with 'byte_to_string'
##

sub xml_decode {
    my ($st) = @_;

    if (defined $st) {
	
	$st =~ s/&amp\;/&/g;
	$st =~ s/&lt\;/</g;
	$st =~ s/&gt\;/>/g;
	$st =~ s/&quot\;/\"/g;
	$st =~ s/&apos\;/\'/g;
	
	$st =~ s/&\#x(.{4});/chr(hex $1)/ge;
	$st =~ s/&\#(.{2,3});/chr($1)/ge;
    }

    return $st;
}



##
##
## OBJECT METHODS:
## ---------------
##



##----------------------------------------------------------------------------------------
##
## new IDMEF()
##
## RETURN
##   a new empty IDMEF message
##
## DESC
##   create a new empty idmef message, and return the hash structure containing it.
##   wrapper to a in("") call.
##
## EXAMPLES:
##   $idmef = new XML::IDMEF();
##

sub new {
    return(in(""));
}



##----------------------------------------------------------------------------------------
##
## in(<idmef>, <string>)
##
## ARGS:
##   <idmef>   idmef object
##   <string>  can be either a path to an IDMEF file to load, or an IDMEF string.
##             if it is an empty string, a new empty IDMEF message is created.
## RETURN:
##   a hash to the loaded IDMEF message
##
## DESC:
##   loads an idmef message into an IDMEF container (a hash with XML::Simple syntax)
##   the input can either be a string, a file or an empty string.
##
## EXAMPLES:
##   my $idmef = (new XML::IDMEF)->in("/home/user/idmef.xml");
##   $idmef = $idmef->in("<IDMEF-Message version=\"0.5\"></IDMEF-Message>");
##

sub in {
    #remove keeproot if there is a higher tag than Alert (<idmef...>)
    my($idmef, $arg) = @_;

    $arg = "" if (!defined($arg));

    # if got empty string, create a new empty idmef, otherwise load/parse it
    $arg = EMPTYIDMEF if ($arg eq "");

    $idmef = XMLin($arg, keyattr=>[], forcearray=>1, keeproot=>0, contentkey=>CONTENTKEY);
    
    bless($idmef, "XML::IDMEF");
    return $idmef;
}



##----------------------------------------------------------------------------------------
##
## out(<hash>)
##
## ARGS:
##   <hash>  hash containing an IDMEF message in XML::Simple representation
##
## RETURN:
##   a string containing the corresponding IDMEF message
##
## EXAMPLES:
##    $string = $idmef->out();
##

sub out {
    my($idmef, $simple, $key, $out);
    $idmef = shift;

    # bad hack: could not 're-bless' $idmef to 'XML::Simple', so build a new and copy
    $simple = XMLin("<IDMEF-Message></IDMEF-Message>", keyattr=>[], forcearray=>1, keeproot=>0,
		    contentkey=>CONTENTKEY);
    foreach $key (keys(%{$idmef})) {
	$simple->{$key} = $idmef->{$key};	
    }

    #TODO: insert here code checking $idmef against IDMEF DTD

    $out = XMLout($simple, rootname=>'IDMEF-Message', contentkey=>CONTENTKEY);

    # bad hack: Simple does not replace &<>"' correctly, nor does it handle &#....;,
    # so we have to clean after:
    $out =~ s/&amp;/&/g;

    return $out;
}



##----------------------------------------------------------------------------------------
##
## get_type(<hash>)
##
## ARGS:
##   <hash>  hash containing an IDMEF message in XML::Simple representation
##
## RETURN:
##   a string representing the type of IDMEF message ("Alert", "Heartbeat"...)
##   or undef if this message does not have a type yet.
##
## EXAMPLES:
##   $idmef = new XML::IDMEF();
##   $idmef->add("Alertimpact", "7");
##   $type = $idmef->get_type();   # $type now contains the string "Alert"   
##

sub get_type {
    my $idmef = shift;
    
    foreach my $k (keys %{$idmef}) {
	return $k if ($k ne "version");
    }
    return undef;
}



##----------------------------------------------------------------------------------------
##
## to_hash(<hash>)
##
## ARGS:
##   <hash>  hash containing an IDMEF message in XML::Simple representation
##
## RETURN:
##   a hash enumerating all the contents and attributes of this IDMEF message.
##   each key is a concatenated sequence of tags leading to the content/attribute,
##   and the corresponding value is the content/attribute itself.
##   all IDMEF contents and values are converted from IDMEF format (STRING or BYTE)
##   back to the original ascii string.
##
## EXAMPLES:
##
## <IDMEF-message version="0.5">
##  <Alert ident="myalertidentity">
##    <Target>
##      <Node category="dns">
##        <name>node2</name>
##      </Node>
##    </Target>
##    <AdditionalData meaning="datatype1">data1</AdditionalData>
##    <AdditionalData meaning="datatype2">data2</AdditionalData>
##  </Alert>
## </IDMEF-message>
##
## becomes:
##
## { "version"                    => [ "0.5" ],
##   "Alertident"                 => [ "myalertidentity" ],
##   "AlertTargetNodecategory"    => [ "dns" ],
##   "AlertTargetNodename"        => [ "node2" ],
##   "AlertAdditionalDatameaning" => [ "datatype1", "datatype2" ],   #meaning & contents are
##   "AlertAdditionalData"        => [ "type1", "type2" ],           #listed in same order
## }
##
##

sub to_hash {
    my $idmef = shift;
    my $result = {};
    my $path = [];

    simplehashtohash($idmef, $path, $result);
    return $result;
}


# recursive functions called by to_hash
# goes through the XML::Simple hash tree representing the IDMEF message
# and build a hash of keys as returned by to_hash

sub simplehashtohash {
    my($hash, $path, $result) = @_;
    my($key, $node);

    foreach $key (keys %{$hash})
    {
	push @{$path}, $key if ($key ne CONTENTKEY);
		  
	if (ref($hash->{$key}) eq "ARRAY")
	{
	    # this is an array of sub-nodes. let's loop through it.
	    foreach $node (@{$hash->{$key}}) {
		
		if (ref($node) eq "HASH") {
		    simplehashtohash($node, $path, $result);
		} else {
		    add_pathkey_in_result($result, $path, $node);
		}
	    }
	}
	else
	{
	    # we reached a key->value pair. put it in $result
	    add_pathkey_in_result($result, $path, $hash->{$key});
	}

	pop @{$path} if ($key ne CONTENTKEY);
    }
}


# take $result, $path, $key and add join($path)->"$key" to $result

sub add_pathkey_in_result {
    my($result, $path, $key) = @_;
    my $tagpath = join '', @{$path};

    $key = xml_decode($key);

    if (exists($result->{$tagpath})) {
	push @{$result->{$tagpath}}, $key;
    } else {
	$result->{$tagpath} = [ $key ];
    }
}



#----------------------------------------------------------------------------------------
#
# add_in_simplehash(hash, hash2, type, index, tag1, tag2, ..., tagN-1, tagN);
#
# ARGS:
#   hash:          hash containing an XML message in XML::Simple representation
#   hash2:         the same hash. required by function's internals.
#   type:          type of field being inserted: 'T' for a tag, 'N' for a node
#                  and 'A' for an attribute
#   index:         index of the tag being analyzed at this level of recurrence
#                  should be 0 when calling add_in_simplehash from another function.
#   tag1...tagN-1: strings representing nested IDMEF tags
#   tagN-1:        if tagN is a content of tag tagN-2, tagN-1 should be the
#                  keyword CONTENTKEY
#   tagN:          value of content or attribute
#
# RETURN: 
#   1 if the key was inserted, 0 otherwise
#
# DESC:
#   Don't use this functions, use add(...) instead.
#   Function performs basic checks and dies if it reaches an impossible
#   state.
#   It recursively searches the IDMEF tree contained by 'hash' to find where
#   to add the given key.
#   Special treatment for AdditionalData nodes: instead of looking through all
#   AdditionalData nodes available, just look at the last one
#

sub add_in_simplehash {
    my ($roothash, $hash, $type, $index, @path, $path_size, $field, @nodes, @subpath);

    ($roothash, $hash, $type, $index, @path) = @_;
    $path_size  = @path;
    $field      = $path[$index];

    die "add_in_simplehash: got no path" if ($path_size == 0);
    die "add_in_simplehash: got index larger than path " if ($index > $path_size);
    die "add_in_simplehash: can't add a unique key $path[0] which is not a node" 
	if ( ($path_size == 1) && ($type ne 'N') );
    
    $path_size-- if ($type ne 'N');    

    # have we reached the last field in path.
    if ($index == $path_size-1)
    {
	# check if field exists in hash
	if (exists($hash->{$field})) {

	    # field exist. can it exist in multiple number?
	    if (!is_multiple($path[$index-1], $field)) {
		# field can exist only once in this node, and it has already been
		# created: need to find the closest higher node that can be multiple,
		# duplicate it and drop our key there
		# TODO
		
		while ($index > 0) {
		    $index--;
		    if (is_multiple($path[$index-1], $path[$index])) {
			
			# fork the tag tree at closest node that can be multiple
			@subpath = @path;
			splice @subpath, $index+1;
			add_in_simplehash($roothash, $roothash, 'N', 0, @subpath);
			
			# restart the key insertion process
			return add_in_simplehash($roothash, $roothash, $type, 0, @path);
		    }
		}
		die "add_in_simple_hash: can't add field $field. it already exists and can't be multiple.";
	    }
	}

	# field does not exist or accepts multiple values. create key
	if ($type eq 'N') {
	    simplehash_add_key($hash, $type, $field);
	} else {
	    simplehash_add_key($hash, $type, $field, $path[$index+1]);
	}
	return 1;
    }

    # we have not yet reached the last field. let's open or create a node

    # create a node if it does not exist
    simplehash_add_key($hash, 'N', $field) if (!exists($hash->{$field}));

    # take the first instance of this node, and continue in it
    @nodes = @{$hash->{$field}};
    return add_in_simplehash($roothash, $nodes[0], $type, $index+1, @path);
}
    
    

# simplehash_add_key($hash, $type, $key, $value);
#   add key=>value to $hash depending on whether $value
#   is a tag, content or attribut ($type)
#   to add a node, just do ...add_key($hash, $type, $key)
#   (key = nodename)

sub simplehash_add_key {
    my ($hash, $type, $key, $val) = @_;

    # add NODE
    if ($type eq 'N')
    {
	if (exists($hash->{$key})) {
	    # add an empty node to the node list, IN FIRST POSITION
	    $hash->{$key} = [ {}, @{$hash->{$key}} ];
	} else {
	    # create an empty node
	    $hash->{$key} = [{}];
	}
    }
    # add ATTRIBUTE
    elsif ($type eq 'A')
    {
	# create an attribute hask key
	$hash->{$key} = $val;
    }
    # add TAG
    elsif ($type eq 'T')
    {
	if ($key eq CONTENTKEY)	{
	    # in XML::Simple hash, the CONTENTKEY tag is actually an attribute
	    $hash->{$key} = $val;
	} else {    
	    if (exists($hash->{$key})) {
		# tag array exist. add it a value
		push @{$hash->{$key}}, $val;
	    } else {
		# create tag array with 1 value
		$hash->{$key} = [$val];
	    }
	}
    }
}


	    
# is_multiple(<rootnode>, <node>)
#   check is <node> can occur multiple times in <rootnode>
#   according to the IDMEF DTD. return 1 if yes, 0 if no.
#

sub is_multiple {
    my ($class, $flag, $rootnode, $node, $k);
    ($rootnode, $node) = @_;

    $class = $IDMEF_DTD->{$rootnode};

    if (exists($class->{MULTI})) {
	foreach $k (@{$class->{MULTI}}) {
	    return 1 if ($k eq $node);
	}
    }
    return 0;
}



#----------------------------------------------------------------------------------------
#
# check_allowed(path, key, list);
#   check that key is one of elements of list
#   returns 1 if ok, 0 if st1 is not in and
#   send error

sub check_allowed {
    my ($path, $key, $v, @vals);
    ($path, $key, @vals)= @_;

    foreach $v (@vals) {
	return 1 if ($v eq $key);
    }

    croak "add: $key is not an allowed value for $path.\n";
    return 0;
}



##----------------------------------------------------------------------------------------
##
## add(hash, tagpath, value)
## 
## ARGS:
##   hash:    a hash representation of an IDMEF message, as received from new or in
##   tagpath: a string obtained by concatenating the names of the nested tags, from the
##            Alert tag down to the closest tag to value.
##   value:   the value (content of a tag, or value of an attribute) of the last tag
##            given in tagpath
##
## RETURN:
##   1 if the field was correctly added, 0 otherwise
##
## DESC:
##   Each IDMEF field of a given IDMEF message can be created through a corresponding add()
##   call. These interfaces are designed for easily building a new IDMEF message while
##   parsing a log file. The 'tagpath' is the same as returned by the 'to_hash' call.
##
## RESTRICTIONS:
##   You cannot change an attribute value with add(). An attempt to run add() on an attribute 
##   that already exists will just be ignored. Contents cannot be changed either, but a new 
##   tag can be created if you are adding an idmef content that can occur multiple time (ex:
##   UserIdname, AdditionalData...).
##
## SPECIAL CASE: AdditionalData
##   AdditionalData is a special tag requiring at least 2 add() calls to build a valid node. In 
##   case of multiple AdditionalData delaration, take care of building AdditionalData nodes one 
##   at a time, and always begin by adding the "AddtitionalData" field (ie the tag's content).
##   Otherwise, the idmef key insertion engine will get lost, and you'll get scrap.
##
##   As a response to this issue, the 'add("AlertAdditionalData", "value")' call accepts an
##   extended syntax compared with other calls:
##
##   add("AlertAdditionalData", <value>);   
##      => add the content <value> to Alert/AdditionalData
##
##   add("AlertAdditionalData", <value>, <meaning>); 
##      => same as:  (type string is assumed by default)
##         add("AlertAdditionalData", <value>); 
##         add("AlertAdditionalDatameaning", <meaning>); 
##         add("AlertAdditionalDatatype", "string");
##
##   add("AlertAdditionalData", <value>, <meaning>, <type>); 
##      => same as: 
##         add("AlertAdditionalData", <value>); 
##         add("AlertAdditionalDatameaning", <meaning>); 
##         add("AlertAdditionalDatatype", <type>);
##
##   The use of add("AlertAdditionalData", <arg1>, <arg2>, <arg3>); is prefered to the simple
##   add call, since it creates the whole AdditionalData node at once. In the case of 
##   multiple arguments add("AlertAdditionalData"...), the returned value is 1 if the type key
##   was inserted, 0 otherwise.
##
##
## EXAMPLES:
##
##   my $idmef = new XML::IDMEF();
##
##   $idmef->add("Alertimpact", "<value>");     
##
##   $idmef->add($idmef, "AlertTargetUserUserIdname", "<value>");
##
##   # AdditionalData case:
##   # DO:
##   $idmef->add("AlertAdditionalData", "value");           # content add first
##   $idmef->add("AlertAdditionalDatatype", "string");      # ok
##   $idmef->add("AlertAdditionalDatameaning", "meaning");  # ok
##
##   $idmef->add("AlertAdditionalData", "value2");          # content add first 
##   $idmef->add("AlertAdditionalDatatype", "string");      # ok
##   $idmef->add("AlertAdditionalDatameaning", "meaning2"); # ok
##
##   # or BETTER:
##   
##   $idmef->add("AlertAdditionalData", "value", "meaning", "string");  # VERY GOOD
##   $idmef->add("AlertAdditionalData", "value2", "meaning2");          # VERY GOOD (string type is default)
##
##
##   # DO NOT DO:
##   $idmef->add("AlertAdditionalData", "value");           # BAD!! content should be declared first
##   $idmef->add("AlertAdditionalDatameaning", "meaning2"); # BAD!! content first!
##
##   # DO NOT DO:
##   $idmef->add("AlertAdditionalData", "value");           # BAD!!!!! mixing node declarations
##   $idmef->add("AlertAdditionalData", "value2");          # BAD!!!!! for value & value2
##   $idmef->add("AlertAdditionalDatatype", "string");      # BAD!!!!! 
##   $idmef->add("AlertAdditionalDatatype", "string");      # BAD!!!!!
##
##

sub add {
    my ($tag1, $tag2);
    my ($idmef, $path, $value, @tail) = @_;

    $value = xml_encode($value);

    # check if value is valid
    if (exists($CHECK_VALUE->{$path})) {
	check_allowed($path, $value, @{$CHECK_VALUE->{$path}});
    }

    # check if path valid and add key
    if (exists($EXPAND_PATH->{$path})) {
	
	$tag1 = @{$EXPAND_PATH->{$path}}[2];
	$tag2 = @{$EXPAND_PATH->{$path}}[3];  
	
	# check if it is AdditionalData	
	if ($tag2 eq "AdditionalData") {

	    if ($#tail == -1) {
		return add_in_simplehash($idmef, $idmef, @{$EXPAND_PATH->{$path}}, $value);
	    } elsif ($#tail == 0) {
		add_in_simplehash($idmef, $idmef, @{$EXPAND_PATH->{$path}}, $value);
	        add_in_simplehash($idmef, $idmef, @{$EXPAND_PATH->{$path."meaning"}}, xml_encode($tail[0]));
		return add_in_simplehash($idmef, $idmef, @{$EXPAND_PATH->{$path."type"}}, "string");
	    } elsif ($#tail == 1) {
		check_allowed($path."type", xml_encode($tail[1]), @{$CHECK_VALUE->{$path."type"}});
		add_in_simplehash($idmef, $idmef, @{$EXPAND_PATH->{$path}}, $value);
		add_in_simplehash($idmef, $idmef, @{$EXPAND_PATH->{$path."meaning"}}, xml_encode($tail[0])); 	
		return add_in_simplehash($idmef, $idmef, @{$EXPAND_PATH->{$path."type"}}, xml_encode($tail[1]));
	    } else {
		croak "add: wrong number of arguments given to add(\"$path\")";
	    }
	}
	else
	{
	    if (defined $value) {
		return add_in_simplehash($idmef, $idmef, @{$EXPAND_PATH->{$path}}, $value);
	    } else {
		return add_in_simplehash($idmef, $idmef, @{$EXPAND_PATH->{$path}});
	    }
	}
    }    

    croak "add: $path is not a known IDMEF tag path\n";
}



##----------------------------------------------------------------------------------------
##
## create_ident(<idmef>)
##
## ARGS:
##   <idmef>       idmef message object
##
## RETURN: 
##   nothing.
##
## DESC:
##   Set the root ident attribute field of this IDMEF message with a unique,
##   randomly generated ID number. The code for the ID number generator is actually 
##   inspired from Sys::UniqueID. If no IDMEF type is given, "Alert" is assumed as default.
##
##

sub create_ident {
    my($id, $idmef, $name, $netaddr);
    $idmef = shift;

    $name = $idmef->get_type();
    $name = "Alert" if (!defined $name);

    # code cut n paste from Sys::UniqueID
    # absolutely ensure that id is unique: < 0x10000/second
    #$netaddr= sprintf '%02X%02X%02X%02X', (split /\./, hostip);
    $netaddr = int(rand 10000000); # random instead of ip

    unless(++$idnum < 0x10000) { sleep 1; $idnum= 0; }
    $id =  sprintf '%012X%s%08X%04X', time, $netaddr, $$, $idnum;

    add($idmef, $name."ident", $id);        
}



##----------------------------------------------------------------------------------------
##
## create_time(<idmef>)
##
## ARGS:
##   <idmef>       idmef message object
##
## RETURN: 
##   nothing.
##
## DESC:
##   Set the CreateTime field of this idmef message with the current time
##   in both the content and ntpstamp fields. If no IDMEF type is given,
##   "Alert" is assumed as default.
##
##

sub create_time {
    my $idmef = shift;

    my $name = $idmef->get_type();
    $name = "Alert" if (!defined $name);

    # add time stamp
    my $utc = time;
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime($utc);
    $year =~ s/^1/20/;
    $mon  = "0".$mon  if (length($mon) == 1);
    $mday = "0".$mday if (length($mday) == 1);
    $hour = "0".$hour if (length($hour) == 1);
    $min  = "0".$min  if (length($min) == 1);
    $sec  = "0".$sec  if (length($sec) == 1);
    add($idmef, $name."CreateTime", "$year-$mon-$mday"."T$hour:$min:$sec"."Z");

    # add ntp stamp (cf rfc 1305 for a definition of ntpstamps) 
    # "At 0h on 1 January 1972 (MJD 41,317.0), the
    # first tick of the UTC Era, the NTP clock was set to 2,272,060,800,
    # re presenting the number of standard seconds since 0h on 1 January 1900"
    $utc = $utc + 2272060800;

    # translate utc to hex!!
    $utc = sprintf "%x", $utc;

    add($idmef, $name."CreateTimentpstamp", "0x$utc.0x0");    
}

sub padd_with_zero {
    my $d = $_[0];
    $d = "0".$d if (length($d) == 1);    
    return $d;
}



#----------------------------------------------------------------------------------------
#
# END OF CODE - START OF POD DOC
#
#----------------------------------------------------------------------------------------


1;

__END__

=pod

=head1 NAME

XML::IDMEF - A module for building/parsing IDMEF messages

=head1 QUICK START

Below is an example of Alert IDMEF message.

    <IDMEF-Message version="0.5">
      <Alert>
        <AdditionalData meaning="data2" type="string">value2</AdditionalData>
        <AdditionalData meaning="data1" type="string">value1</AdditionalData>
        <Target>
          <Node>
            <name>mynode</name>
          </Node>
        </Target>
        <Analyzer model="myids" />
      </Alert>
    </IDMEF-Message>

The previous IDMEF message can be built with the following code snipset:

    use XML::IDMEF;   

    my $idmef = new XML::IDMEF();  

    $idmef->add("AlertTargetNodename", "mynode");
    $idmef->add("AlertAdditionalData", "value1", "data1"); 
    $idmef->add("AlertAdditionalData", "value2", "data2");
    $idmef->add("AlertAnalyzermodel", "myids");

    print $idmef->out();

To automatically insert an Alert ident tag and set the CreateTime class to the current time, add the 2 lines:

    $idmef->create_ident();
    $idmef->create_time();

and you will get:

    <IDMEF-Message version="0.5">
      <Alert ident="00003D9047B8722743900005A3F0001">
        <AdditionalData meaning="data2" type="string">value2</AdditionalData>
        <AdditionalData meaning="data1" type="string">value1</AdditionalData>
        <CreateTime ntpstamp="0xc4fd2d38.0x0">2002-08-24T11:08:40Z</CreateTime>
        <Target>
          <Node>
            <name>mynode</name>
          </Node>
        </Target>
        <Analyzer model="myids" />
      </Alert>
    </IDMEF-Message>

=head1 DESCRIPTION

IDMEF.pm is an interface for simply creating and parsing IDMEF messages. IDMEF is an XML based standard for representing Intrusion Detection related messages (http://www.silicondefense.com/idwg/).

IDMEF.pm is compliant with IDMEF v0.5, and hence provides calls for building Alert, ToolAlert, CorrelationAlert, OverflowAlert and Heartbeat IDMEF messages.
    
This interface has been designed for simplifying the task of translating a key-value based format to its idmef representation, which is the most common situation when writing a log export module for a given software. A typical session involves the creation of a new IDMEF message, the initialisation of some of its fields and its conversion into an IDMEF string (see example in QUICK START).

An interface to load and parse an IDMEF message is also provided (with the 'to_hash' function).

This module contains a generic XML DTD parser and includes a class based definition of the IDMEF DTD. It can hence easily be upgraded or extended to support new XML nodes. For information on how to extend IDMEF with IDMEF.pm, read the documentation in the source code.
    
This code is distributed under the BSD license, and with the support of Proact Defcom AB, Stockholm, Sweden.

=head1 EXPORT

    xml_encode
    xml_decode
    byte_to_string
    extend_idmef	

=head1 AUTHOR

Erwan Lemonnier - erwan@cpan.org

=head1 LICENSE

This code was developed with the support of Proact Defcom AB, Stockholm, Sweden, and is released under the BSD license.

=head1 SEE ALSO

XML::Simple, XML::Parser, XML::Expat, libexpat

=head1 SYNOPSIS

In the following, function calls and function parameters are passed in a perl object-oriented fashion. Hence, some functions (object methods) are said to not take any argument, while they in fact take an IDMEF object as first argument. Refer to the examples in case of confusion. The function listed at the end (C<xml_encode>, C<xml_decode>, C<byte_to_string> are on the other hand class methods, and should not be called on an IDMEF object.

=head1 OBJECT METHODS

=over 4

=item B<new>()

=over 4

=item B<ARGS> none.

=item B<RETURN>

a new empty IDMEF message.

=item B<DESC>

C<new> creates and returns a new empty IDMEF message. Use C<add()>, C<create_ident()> and C<create_time()> to add fields to this message.

=item B<EXAMPLES>

 my $idmef = new XML::IDMEF;

=back  




=item $idmef->B<in>([PATH|STRING])

=over 4

=item B<ARGS>

I<PATH|STRING>: either an IDMEF message as a string or a path to a file containing an IDMEF message.

=item B<RETURN>

the IDMEF object corresponding to this IDMEF message.

=item B<DESC>

C<in> creates a new IDMEF message from either a string C<STRING> or a file located at the path C<PATH>. If no argument is provided, an empty IDMEF message is created and returned.

=item B<EXAMPLES>

 my $idmef = (new XML::IDMEF)->in("idmef.file");
 my $idmef = $idmef->in();

=back




=item $idmef->B<out>()

=over 4
 
=item B<ARGS> none.

=item B<RETURN>
   
a string representing this IDMEF object.

=item B<DESC>
   
C<out> returns the IDMEF message as a string.

=item B<EXAMPLES>
   
 print $idmef->out;

=back




=item $idmef->B<create_ident>()

=over 4

=item B<ARGS> none.

=item B<RETURN> nothing.

=item B<DESC>
   
C<create_ident> generates a unique IDMEF ident tag and inserts it into this IDMEF message. The tag is generated base on the local time, a random number, the process pid and an internal counter. If the IDMEF message does not yet have a type, it will become 'Alert' by default.

=item B<EXAMPLES>

 $idmef->create_ident();

=back




=item $idmef->B<create_time>()

=over 4

=item B<ARGS> none.

=item B<RETURN> nothing.

=item B<DESC>  
   
C<create_time> sets the IDMEF CreateTime node to the current time. It sets both the ntpstamp and the UTC time stamps of CreateTime.

=item B<EXAMPLES>
   
 $idmef->create_time();

=back




=item $idmef->B<get_type>()

=over 4

=item B<ARGS> none.

=item B<RETURN>
   
the type of this IDMEF message, as a string.

=item B<DESC>
   
C<get_type> returns the type of this IDMEF message as a string. An 'Alert' IDMEF message would for example return "Alert".

=item B<EXAMPLES>
   
 $string_type = $idmef->get_type();

=back 




=item $idmef->B<add>($tagpath, $value)

=over 4

=item B<ARGS>

I<$idmef>: a hash representation of an IDMEF message, as received from C<new> or C<in>.

I<$tagpath>: a string obtained by concatenating the names of the nested XML tags, from the Alert tag down to the closest tag to value.

I<$value>: the value (content of a tag, or value of an attribute) of the last tag given in tagpath.

=item B<RETURN>
   
1 if the field was correctly added, 0 otherwise.

=item B<DESC>

Each IDMEF content/value of a given IDMEF message node can be created through an appropriate add() call. A 'tagpath' is a string obtained by concatenating the names of the XML nodes from the top 'Alert' node down to the attribute or content whose value we want to set. Hence, in the example given in introduction, the tagpath for setting the value of the Alert Analyzer model attribute is 'AlertAnalyzermodel'.

The C<add> call was designed for easily building a new IDMEF message while parsing a log file, or any data based on a key-value format.

=item B<RESTRICTIONS>

C<add> cannot be used to change the value of an already existing content or attribute. An attempt to run add() on an attribute that already exists will just be ignored. Contents cannot be changed either, but a new tag can be created if you are adding an idmef content that can occur multiple time (ex: UserIdname, AdditionalData...).

=item B<SPECIAL CASE: AdditionalData>

AdditionalData is a special tag requiring at least 2 add() calls to build a valid node. In case of multiple AdditionalData delarations, take care of building AdditionalData nodes one at a time, and always begin by adding the "AddtitionalData" field (ie the tag content). Otherwise, the idmef key insertion engine will get lost, and you will get scrap.

As a response to this issue, the 'add("AlertAdditionalData", "value")' call accepts an extended syntax compared with other calls:

   add("AlertAdditionalData", <value>);   
      => add the content <value> to Alert AdditionalData

   add("AlertAdditionalData", <value>, <meaning>); 
      => same as:  (type "string" is assumed by default)
         add("AlertAdditionalData", <value>); 
         add("AlertAdditionalDatameaning", <meaning>); 
         add("AlertAdditionalDatatype", "string");

   add("AlertAdditionalData", <value>, <meaning>, <type>); 
      => same as: 
         add("AlertAdditionalData", <value>); 
         add("AlertAdditionalDatameaning", <meaning>); 
         add("AlertAdditionalDatatype", <type>);

The use of add("AlertAdditionalData", <arg1>, <arg2>, <arg3>) is prefered to the simple C<add> call, since it creates the whole AdditionalData node at once. In the case of multiple arguments C<add("AlertAdditionalData"...)>, the returned value is 1 if the type key was inserted, 0 otherwise.

=item B<EXAMPLES>

 my $idmef = new XML::IDMEF();

 $idmef->add("Alertimpact", "<value>");     

 $idmef->add($idmef, "AlertTargetUserUserIdname", "<value>");

 # AdditionalData case:
 # DO:
 $idmef->add("AlertAdditionalData", "value");           # content add first
 $idmef->add("AlertAdditionalDatatype", "string");      # ok
 $idmef->add("AlertAdditionalDatameaning", "meaning");  # ok

 $idmef->add("AlertAdditionalData", "value2");          # content add first
 $idmef->add("AlertAdditionalDatatype", "string");      # ok
 $idmef->add("AlertAdditionalDatameaning", "meaning2"); # ok

 # or BETTER:
 $idmef->add("AlertAdditionalData", "value", "meaning", "string");  # VERY GOOD
 $idmef->add("AlertAdditionalData", "value2", "meaning2");          # VERY GOOD (string type is default)


 # DO NOT DO:
 $idmef->add("AlertAdditionalData", "value");           # BAD!! content should be declared first
 $idmef->add("AlertAdditionalDatameaning", "meaning2"); # BAD!! content first!

 # DO NOT DO:
 $idmef->add("AlertAdditionalData", "value");           # BAD!!!!! mixing node declarations
 $idmef->add("AlertAdditionalData", "value2");          # BAD!!!!! for value & value2
 $idmef->add("AlertAdditionalDatatype", "string");      # BAD!!!!! 
 $idmef->add("AlertAdditionalDatatype", "string");      # BAD!!!!!

=back




=item $idmef->B<to_hash>()

=over 4

=item B<ARGS> none.

=item B<RETURN>
   
the IDMEF message flattened inside a hash.

=item B<DESC>
   
C<to_hash> returns a hash enumerating all the contents and attributes of this IDMEF message. Each key is a concatenated sequence of XML tags (a 'tagpath', see C<add()>) leading to the content/attribute, and the corresponding value is an array containing the content/attribute itself. In case of multiple occurences of one 'tagpath', the corresponding values are listed as elements of the array (See the example). All IDMEF contents and values are converted from IDMEF format (STRING or BYTE) back to the original ascii string.

=item B<EXAMPLES>

 <IDMEF-message version="0.5">
   <Alert ident="myalertidentity">
     <Target>
       <Node category="dns">
         <name>node2</name>
       </Node>
     </Target>
     <AdditionalData meaning="datatype1">data1</AdditionalData>
     <AdditionalData meaning="datatype2">data2</AdditionalData>
   </Alert>
 </IDMEF-message>
 
 becomes:
  
 { "version"                    => [ "0.5" ],
   "Alertident"                 => [ "myalertidentity" ],
   "AlertTargetNodecategory"    => [ "dns" ],
   "AlertTargetNodename"        => [ "node2" ],
   "AlertAdditionalDatameaning" => [ "datatype1", "datatype2" ],   # meaning & contents are
   "AlertAdditionalData"        => [ "type1", "type2" ],           # listed in same order
 }

=back




=head1 CLASS METHODS




=item B<xml_encode>($string)

=over 4

=item B<ARGS>
   
I<$string>: a usual string

=item B<RETURN>
   
the xml encoded string equivalent to I<$string>. 

=item B<DESC>
   
You do not need this function if you are using add() calls (which already calls it). To convert a string into an idmef STRING, xml_encode basically replaces the following characters: with:

         &                 &amp;
         <                 &lt;
         >                 &gt;
         "                 &quot;
         '                 &apos;

REM: if you want to convert data to the BYTE[] format, use 'byte_to_string' instead

=back




=item B<xml_decode>($string)

=over 4

=item B<ARGS>
   
I<$string>: a string encoded using xml_encode.

=item B<RETURN>
   
the corresponding decoded string.

=item B<DESC>
   
You do not need this function with 'to_hash' (which already calls it). It decodes <xmlstring> into a string, ie replaces the following characters:         with:
         &amp;              &
         &lt;               <
         &gt;               >
         &quot              "
         &apos              '
         &#xx;              xx in base 10
         &#xxxx;            xxxx in base 16
   
It also decodes strings encoded with 'byte_to_string'

=back




=item B<byte_to_string>($bytes)

=over 4

=item B<ARGS>
   
I<$bytes>: a binary string. 

=item B<RETURN>
   
The string obtained by converting <bytes> into its IDMEF representation, refered to as type BYTE[] in the IDMEF rfc.

=item B<DESC>
   
converts a binary string into its BYTE[] representation, according to the IDMEF rfc.

=back




=item B<extend_subclass>($IDMEF-class, $Extended-subclass)

=over 4

=item B<ARGS>
   
I<$IDMEF-class>: an extension class DTD
   
I<$Extended-subclass>: the name of the extended class's root

=item B<RETURN> nothing.

=item B<DESC>

C<extend_subclass> allows to extend the IDMEF DTD by registring new subclasses to classes from the standard IDMEF DTD. Internally, the IDMEF.pm module is built around a DTD parser, which reads an XML DTD (written in a proprietary but straightforward format) and provides functions to build and parse XML messages compliant with this DTD. This DTD parser and its API could be used for any other XML format than IDMEF, provided that the appropriate DTD gets loaded in the module. C<extend_subclass> allows to inject new subclasses of pre-loaded DTD classes into the IDMEF.pm DTD engine.

 ex: extend_sublass($IDMEF-class, $Extended-subclass);

The format of the $xxx-class is too complex to be described here. Refer to the documentation inside the source code.

=back

=cut
























