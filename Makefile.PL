use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'XML::IDMEF',
    'VERSION_FROM'	=> 'IDMEF.pm', # finds $VERSION
    'PREREQ_PM'		=> { 'XML::Simple'        => '0',
                             'XML::Parser'        => '0',
                             'XML::Parser::Expat' => '0', 
                           }, 
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT   => 'IDMEF library for parsing/creating IDMEF messages',
       AUTHOR     => 'Erwan Lemonnier (erwan@cpan.org)') : ()),
);
