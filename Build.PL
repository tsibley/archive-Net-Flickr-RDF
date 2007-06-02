# $Id: Build.PL,v 1.13 2007/05/31 15:15:12 asc Exp $

use strict;
use Module::Build;

my $build = Module::Build->new(module_name => 'Net::Flickr::RDF',
			       # dist_author
			       # dist_abstract
			       dist_version_from => 'lib/Net/Flickr/RDF.pm',
			       license           => 'perl',
			       requires => {
                                            'perl'               => '>= 5.8.0',
                                            'Net::Flickr::API'   => '>= 1.65',
                                            'RDF::Simple'        => '>= 0.22',
                                            'Date::Parse'        => '>= 2.27',
                                            'Date::Format'       => '>= 2.22',
                                            'Readonly'           => '0',
			       },
			       build_requires => {
				   'Test::Simple' => '>= 0.47',
			       },
			       create_readme      => 1,
			       create_makefile_pl => 'passthrough');

$build->create_build_script();
