use 5.000;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
   'NAME'          => 'X12',
   'VERSION_FROM'  => 'Parser.pm', # finds $VERSION
   'PREREQ_PM'     => {}, # e.g., Module::Name => 1.1
   'PM' => {
   'Makefile.PL'          => 'Makefile',
   'Parser.pm'            => 'blib/lib/X12/Parser.pm',
   'Cf.pm'                => 'blib/lib/X12/Parser/Cf.pm',
   'cf/270_004010X092.cf' => 'blib/lib/X12/Parser/cf/270_004010X092.cf',
   'cf/271_004010X092.cf' => 'blib/lib/X12/Parser/cf/271_004010X092.cf',
   'cf/276_004010X093.cf' => 'blib/lib/X12/Parser/cf/276_004010X093.cf',
   'cf/277_004010X092.cf' => 'blib/lib/X12/Parser/cf/277_004010X092.cf',
   'cf/278_004010X094_Req.cf' => 'blib/lib/X12/Parser/cf/278_004010X094_Req.cf',
   'cf/278_004010X094_Res.cf' => 'blib/lib/X12/Parser/cf/278_004010X094_Res.cf',
   'cf/820_004010X061.cf' => 'blib/lib/X12/Parser/cf/820_004010X061.cf',
   'cf/834_004010X095.cf' => 'blib/lib/X12/Parser/cf/834_004010X095.cf',
   'cf/835_004010X091.cf' => 'blib/lib/X12/Parser/cf/835_004010X091.cf',
   'cf/837_004010X096.cf' => 'blib/lib/X12/Parser/cf/837_004010X096.cf',
   'cf/837_004010X097.cf' => 'blib/lib/X12/Parser/cf/837_004010X097.cf',
   'cf/837_004010X098.cf' => 'blib/lib/X12/Parser/cf/837_004010X098.cf',
   },
    'MAN3PODS' => {
    'Parser.pm'  => 'blib/man3/X12::Parser.3',
    'Cf.pm'      => 'blib/man3/X12::Parser::Cf.3',
    'Readme.pod' => 'blib/man3/X12::Parser::Readme.3',
    }
);



