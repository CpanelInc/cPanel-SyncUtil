use ExtUtils::MakeMaker;

WriteMakefile(
    NAME              => 'cPanel::SyncUtil',
    VERSION_FROM      => 'lib/cPanel/SyncUtil.pm',
    PREREQ_PM         => {
        'File::Slurp'       => 0,
        'File::Find'        => 0,
        'Digest::MD5::File' => 0,
        'version'           => 0,
        'Archive::Tar'      => 0,
        'Getopt::Std'       => 0,
    }, 
    ($] >= 5.005 ?     
      (ABSTRACT_FROM  => 'lib/cPanel/SyncUtil.pm', 
       AUTHOR         => 'Daniel Muey <http://drmuey.com/cpan_contact.pl>') : ()),
);
