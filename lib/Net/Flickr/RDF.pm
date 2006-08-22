use strict;

# $Id: RDF.pm,v 1.58 2006/08/18 03:12:32 asc Exp $
# -*-perl-*-

package Net::Flickr::RDF;
use base qw (Net::Flickr::API);

$Net::Flickr::RDF::VERSION = '1.9';

=head1 NAME

Net::Flickr::RDF - a.k.a RDF::Describes::Flickr

=head1 SYNOPSIS

 use Net::Flickr::RDF;
 use Config::Simple;
 use IO::AtomicFile;

 my $cfg = Config::Simple->new("/path/to/my.cfg");
 my $rdf = Net::Flickr::RDF->new($cfg);

 my $fh  = IO::AtomicFile->open("/foo/bar.rdf","w");

 $rdf->describe_photo({photo_id => 123,
                       secret   => 567,
                       fh       => \*$fh});

 $fh->close();

=head1 DESCRIPTION

Describe Flickr photos as RDF.

This package inherits from I<Net::Flickr::API>.

=head1 OPTIONS

Options are passed to Net::Flickr::Backup using a Config::Simple object or
a valid Config::Simple config file. Options are grouped by "block".

=head2 flickr

=over 4

=item * B<api_key>

String. I<required>

A valid Flickr API key.

=item * B<api_secret>

String. I<required>

A valid Flickr Auth API secret key.

=item * B<auth_token>

String. I<required>

A valid Flickr Auth API token.

=back

=cut

use utf8;
use English;

use Date::Format;
use Date::Parse;
use Digest::MD5 qw (md5_hex);
use RDF::Simple::Serialiser;
use Readonly;

Readonly::Hash my %DEFAULT_NS => (
				  "a"       => "http://www.w3.org/2000/10/annotation-ns",
                                  "atom"    => "http://www.w3.org/2005/Atom/",
				  "acl"     => "http://www.w3.org/2001/02/acls#",
				  "cc"      => "http://web.resource.org/cc/",
				  "dc"      => "http://purl.org/dc/elements/1.1/",
				  "dcterms" => "http://purl.org/dc/terms/",
				  "exif"    => "http://nwalsh.com/rdf/exif#",
				  "exifi"   => "http://nwalsh.com/rdf/exif-intrinsic#",
				  "flickr"  => "x-urn:flickr:",
				  "foaf"    => "http://xmlns.com/foaf/0.1/",
				  "geo"     => "http://www.w3.org/2003/01/geo/wgs84_pos#",
				  "i"       => "http://www.w3.org/2004/02/image-regions#",
				  "rdf"     => "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
				  "rdfs"    => "http://www.w3.org/2000/01/rdf-schema#",
				  "skos"    => "http://www.w3.org/2004/02/skos/core#",
				  );

Readonly::Hash my %RDFMAP => (
			      'EXIF' => {
				  '41483' => 'flashEnergy',
				  '33437' => 'fNumber',
				  '37378' => 'apertureValue',
				  '37520' => 'subsecTime',
				  '34855' => 'isoSpeedRatings',
				  '41484' => 'spatialFrequencyResponse',
				  '37380' => 'exposureBiasValue',
				  '532'   => 'referenceBlackWhite',
				  '40964' => 'relatedSoundFile',
				  '36868' => 'dateTimeDigitized',
				  '34850' => 'exposureProgram',
				  '272'   => 'model',
				  '259'   => 'compression',
				  '37381' => 'maxApertureValue',
				  '37396' => 'subjectArea',
				  '277'   => 'samplesPerPixel',
				  '37121' => 'componentsConfiguration',
				  '37377' => 'shutterSpeedValue',
				  '37384' => 'lightSource',
				  '41989' => 'focalLengthIn35mmFilm',
				  '41495' => 'sensingMethod',
				  '37386' => 'focalLength',
				  '529'   => 'yCbCrCoefficients',
				  '41488' => 'focalPlaneResolutionUnit',
				  '37379' => 'brightnessValue',
				  '41730' => 'cfaPattern',
				  '41486' => 'focalPlaneXResolution',
				  '37510' => 'userComment',
				  '41992' => 'contrast',
				  '41729' => 'sceneType',
				  '41990' => 'sceneCaptureType',
				  '41487' => 'focalPlaneYResolution',
				  '37122' => 'compressedBitsPerPixel',
				  '37385' => 'flash',
				  '258'   => 'bitsPerSample',
				  '530'   => 'yCbCrSubSampling',
				  '41993' => 'saturation',
				  '284'   => 'planarConfiguration',
				  '41996' => 'subjectDistanceRange',
				  '41987' => 'whiteBalance',
				  '274'   => 'orientation',
				  '40962' => 'pixelXDimension',
				  '306'   => 'dateTime',
				  '41493' => 'exposureIndex',
				  '40963' => 'pixelYDimension',
				  '41994' => 'sharpness',
				  '315'   => 'artist',
				  '1'     => 'interoperabilityIndex',
				  '37383' => 'meteringMode',
				  '37522' => 'subsecTimeDigitized',
				  '42016' => 'imageUniqueId',
				  '41728' => 'fileSource',
				  '41991' => 'gainControl',
				  '283'   => 'yResolution',
				  '37500' => 'makerNote',
				  '273'   => 'stripOffsets',
				  '305'   => 'software',
				  '531'   => 'yCbCrPositioning',
				  '319'   => 'primaryChromaticities',
				  '278'   => 'rowsPerStrip',
				  '36864' => 'version',
				  '34856' => 'oecf',
				  '271'   => 'make',
				  '282'   => 'xResolution',
				  '37521' => 'subsecTimeOriginal',
				  '262'   => 'photometricInterpretation',
				  '40961' => 'colorSpace',
				  '33434' => 'exposureTime',
				  '33432' => 'copyright',
				  '41995' => 'deviceSettingDescription',
				  '318'   => 'whitePoint',
				  '257'   => 'imageLength',
				  '41988' => 'digitalZoomRatio',
				  '301'   => 'transferFunction',
				  '41985' => 'customRendered',
				  '37382' => 'subjectDistance',
				  '34852' => 'spectralSensitivity',
				  '41492' => 'subjectLocation',
				  '279'   => 'stripByteCounts',
				  '296'   => 'resolutionUnit',
				  '41986' => 'exposureMode',
				  '40960' => 'flashpixVersion',
				  '256'   => 'imageWidth',
				  '36867' => 'dateTimeOriginal',
				  '270'   => 'imageDescription',
			      },
			      
			      GPS => {
				  '11' => 'dop',
				  '21' => 'destLongitudeRef',
				  '7'  => 'timeStamp',
				  '26' => 'destDistance',
				  '17' => 'imgDirection',
				  '2'  => 'latitude',
				  '22' => 'destLongitude',
				  '1'  => 'latitudeRef',
				  '18' => 'mapDatum',
				  '0'  => 'versionId',
				  '30' => 'differential',
				  '23' => 'destBearingRef',
				  '16' => 'imgDirectionRef',
				  '13' => 'speed',
				  '29' => 'dateStamp',
				  '27' => 'processingMethod',
				  '25' => 'destDistanceRef',
				  '6'  => 'altitude',
				  '28' => 'arealInformation',
				  '3'  => 'longitudeRef',
				  '9'  => 'status',
				  '12' => 'speedRef',
				  '20' => 'destLatitude',
				  '14' => 'trackRef',
				  '15' => 'track',
				  '8'  => 'satellites',
				  '4'  => 'longitude',
				  '24' => 'destBearing',
				  '19' => 'destLatitudeRef',
				  '10' => 'measureMode',
				  '5'  => 'altitudeRef',
			      },
			      
			      # TIFF => {},
			  );


Readonly::Hash my %CC_PERMITS => ("by-nc" => {"permits"   => ["Reproduction",
							      "Distribution",
							      "DerivativeWorks"],
					      "requires"  => ["Notice",
							      "Attribution"],
					      "prohibits" => ["CommercialUse"]},
				  "by-nc-nd" => {"permits"   => ["Reproduction",
								 "Distribution"],
						 "requires"  => ["Notice",
								 "Attribution"],
						 "prohibits" => ["CommercialUse"]},
				  "by-nc-sa" => {"permits"   => ["Reproduction",
								 "Distribution",
								 "DerivativeWorks"],
						 "requires"  => ["Notice",
								 "Attribution",
								 "ShareAlike"],
						 "prohibits" => ["CommercialUse"]},
				  "by-nc" =>  {"permits"   => ["Reproduction",
							       "Distribution",
							       "DerivativeWorks"],
					       "requires"  => ["Notice",
							       "Attribution",
							       "ShareAlike"],
					       "prohibits" => ["CommercialUse"]},
				  "by-nd" =>   {"permits"   => ["Reproduction",
								"Distribution"],
						"requires"  => ["Notice",
								"Attribution",
								"ShareAlike"]},
				  "by-sa" =>   {"permits"   => ["Reproduction",
								"Distribution",
								"DerivativeWorks"],
						"requires"  => ["Notice",
								"Attribution",
								"ShareAlike"]},
				  "by" =>   {"permits"   => ["Reproduction",
							     "Distribution",
							     "DerivativeWorks"],
					     "requires"  => ["Notice",
							     "Attribution"]},
				  );

Readonly::Scalar my $FLICKR_URL        => "http://www.flickr.com/";
Readonly::Scalar my $FLICKR_URL_PHOTOS => $FLICKR_URL . "photos/";
Readonly::Scalar my $FLICKR_URL_PEOPLE => $FLICKR_URL . "people/";
Readonly::Scalar my $FLICKR_URL_TAGS   => $FLICKR_URL . "tags/";
Readonly::Scalar my $FLICKR_URL_GROUPS => $FLICKR_URL . "groups/";

Readonly::Scalar my $LICENSE_ALLRIGHTS => "All rights reserved.";

=head1 PACKAGE METHODS

=cut

=head2 __PACKAGE__->new($cfg)

Where B<$cfg> is either a valid I<Config::Simple> object or the path
to a file that can be parsed by I<Config::Simple>.

Returns a I<Net::Flickr::RDF> object.

=cut

# Defined in Net::Flickr::API

=head1 PACKAGE METHODS YOU MAY CARE ABOUT

=cut

=head2 __PACKAGE__->build_photo_uri(\%data)

Returns a URL as a string.

=cut

sub build_photo_uri {
        my $self = shift;
        my $data = shift;

        return sprintf("%s%s/%d",$FLICKR_URL_PHOTOS,$data->{user_id},$data->{photo_id});
}

=head2 __PACKAGE__->build_user_tag_uri(\@data)

Returns a URL as a string.

=cut

sub build_user_tag_uri {
        my $pkg  = shift;
        my $data = shift;
        
        my $clean  = $data->[0];
        my $raw    = $data->[1];
        my $author = $data->[2];
        
        return $FLICKR_URL_PHOTOS."$author/tags/$clean";
}

=head2 __PACKAGE__->build_global_tag_uri(\@data)

Returns a URL as a string.

=cut

sub build_global_tag_uri {
        my $pkg  = shift;
        my $data = shift;
        
        my $clean = $data->[0];
        return $FLICKR_URL_TAGS.$clean;
}

=head2 __PACKAGE__->build_user_uri($user_id)

Returns a URL as a string.

=cut

sub build_user_uri {
        my $pkg     = shift;
        my $user_id = shift;
        
        return $FLICKR_URL_PEOPLE.$user_id;
}

=head2 __PACKAGE__->build_group_uri($group_id)

Returns a URL as a string.

=cut

sub build_group_uri {
        my $self     = shift;
        my $group_id = shift;
        
        return $FLICKR_URL_GROUPS.$group_id;
}

=head2 __PACKAGE__->build_grouppool_uri($group_id)

Returns a URL as a string.

=cut

sub build_grouppool_uri {
        my $self     = shift;
        my $group_id = shift;
        
        return $self->build_group_uri($group_id)."/pool";
}

=head2 __PACKAGE__->build_photoset_uri(\%set_data)

Returns a URL as a string.

=cut

sub build_photoset_uri {
        my $pkg      = shift;
        my $set_data = shift;
        
        return sprintf("%s%s/sets/%s", $FLICKR_URL_PHOTOS, $set_data->{user_id}, $set_data->{id});
}

=head2 __PACKAGE__->prune_triples(\@triples)

Removes duplicate triples from I<@triples>. Returns an array
reference.

=cut

sub prune_triples {
        my $self    = shift;
        my $triples = shift;
        
        my %seen   = ();
        my @pruned = ();
        
        foreach my $spo (@$triples) {
                
                my $key = md5_hex(join("", @$spo));
                
                if (exists($seen{$key})) {
                        next;
                }
                
                $seen{$key} = 1;
                push @pruned, $spo;
        }
        
        return \@pruned;
}

=head1 OBJECT METHODS YOU SHOULD CARE ABOUT

=cut

=head2 $obj->describe_photo(\%args)

Valid arguments are :

=over 4

=item * B<photo_id>

Int. I<required>

=item * B<secret>

String.

=item * B<fh>

File-handle.

Default is STDOUT.

=back

Returns true or false.

=cut

sub describe_photo {
        my $self = shift;
        my $args = shift;
        
        my $fh = ($args->{fh}) ? $args->{fh} : \*STDOUT;
        
        my $data = $self->collect_photo_data($args->{photo_id}, $args->{secret});
        
        if (! $data) {
                return 0;
        }
        
        my $triples = $self->make_photo_triples($data);
        
        if (! $triples) {
                return 0;
        }
        
        $self->serialise_triples($triples,$fh);
        return 1;
}

=head1 OBJECT METHODS YOU MAY CARE ABOUT

=cut

=head2 $obj->collect_photo_data($photo_id,$secret)

Returns a hash ref of the meta data associated with a photo.

If any errors are unencounter an error is recorded via the B<log>
method and the method returns undef.

=cut

sub collect_photo_data {
        my $self   = shift;
        my $id     = shift;
        my $secret = shift;
        
        my %data = ();
        
        my $info = $self->api_call({method=>"flickr.photos.getInfo",
                                    args=>{photo_id => $id,
                                           secret   => $secret}});
        
        if (! $info) {
                $self->log()->error("unable to collect info for photo");
                return undef;
        }
        
        my $img = ($info->findnodes("/rsp/photo"))[0];
        
        if (! $img) {
                $self->log()->error("unable to locate photo for info");
                return undef;
        }
        
        my $owner = ($img->findnodes("owner"))[0];
        my $dates = ($img->findnodes("dates"))[0];
        
        %data = (photo_id => $id,
                 user_id  => $owner->getAttribute("nsid"),
                 title    => $img->find("title")->string_value(),
                 taken    => $dates->getAttribute("taken"),
                 posted   => $dates->getAttribute("posted"),
                 lastmod  => $dates->getAttribute("lastupdate"));
        
        my $owner_id = $data{user_id};
        $data{users}->{$owner_id} = $self->collect_user_data($owner_id);
        
        #
        
        my $sizes = $self->api_call({method => "flickr.photos.getSizes",
                                     args   => {photo_id => $id}});
        
        if (! $sizes) {
                return undef;
        }
        
        foreach my $sz ($sizes->findnodes("/rsp/sizes/size")) {
                
                my $label = $sz->getAttribute("label");
                
                $data{files}->{$label} = {height => $sz->getAttribute("height"),
                                          width  => $sz->getAttribute("width"),
                                          label  => $label,
                                          uri    => $sz->getAttribute("source")};
        }
        
        #
        
        my $cc = $self->collect_cc_data();
        $data{license} = $cc->{$img->getAttribute("license")};
        
        #
        
        my $exif = $self->api_call({method=>"flickr.photos.getExif",
                                    args=>{photo_id => $id,
                                           secret   => $secret}});
        
        if ($exif) {
                foreach my $tag ($exif->findnodes("/rsp/photo/exif[\@tagspace='EXIF']")) {
                        
                        my $facet   = $tag->getAttribute("tagspace");
                        my $tag_dec = $tag->getAttribute("tag");
                        my $value   = $tag->findvalue("clean") || $tag->findvalue("raw");
                        $data{exif}->{$facet}->{$tag_dec} = $value;
                }
        }
        
        #
        
        $data{desc}   = $img->find("description")->string_value();
        
        #
        
        my $vis = ($img->findnodes("visibility"))[0];
        
        if ($vis->getAttribute("ispublic")) {
                $data{visibility} = "public";
        }
        
        elsif (($vis->getAttribute("isfamily")) && ($vis->getAttribute("isfriend"))) {
                $data{visibility} = "family;friend";
        }
        
        elsif ($vis->getAttribute("isfamily")) {
                $data{visibility} = "family";
        }
        
        elsif ($vis->getAttribute("is_friend")) {
                $data{visibility} = "friend";
        }
        
        else {
                $data{visibility} = "private";
        }
        
        #
        
        foreach my $tag ($img->findnodes("tags/tag")) {
                
                my $id     = $tag->getAttribute("id");
                my $raw    = $tag->getAttribute("raw");
                my $clean  = $tag->string_value();
                my $author = $tag->getAttribute("author");
                
                $data{tags}->{$id} = [$clean,$raw,$author];
                $data{tag_map}->{$clean}->{$raw} ++;
                
                $data{users}->{$author} = $self->collect_user_data($author);
        }
        
        #
        
        foreach my $note ($img->findnodes("notes/note")) {
                
                $data{notes} ||= [];
                
                my %note = map {
                        $_ => $note->getAttribute($_);
                } qw (x y h w id author authorname);
                
                $note{body} = $note->string_value();
                push @{$data{notes}}, \%note;
                
                $data{users}->{$note{author}} = $self->collect_user_data($note{author});
        }    	   
        
        #
        
        my $ctx = $self->api_call({method=>"flickr.photos.getAllContexts",
                                   args=>{photo_id=>$id}});
        
        if (! $ctx) {
                $self->log()->warning("unable to retrieve context for photo $id");
        }
        
        else {
                $data{groups} = [];
                $data{sets}   = [];
                
                foreach my $set ($ctx->findnodes("/rsp/set")) {
                        my $set_id = $set->getAttribute("id");
                        
                        push @{$data{sets}},$self->collect_photoset_data($set_id);
                }
                
                foreach my $group ($ctx->findnodes("/rsp/pool")) {
                        my $group_id = $group->getAttribute("id");
                        
                        push @{$data{groups}},$self->collect_group_data($group_id);
                }
        }
        
        #
        #
        #
        
        $data{comments} = $self->collect_comment_data(\%data);
        
        #
        #
        #
        
        return \%data;
}

=head2 $obj->collect_group_data($group_id)

Returns a hash ref of the meta data associated with a group.

If any errors are unencounter an error is recorded via the B<log>
method and the method returns undef.

=cut

sub collect_group_data {
        my $self     = shift;
        my $group_id = shift;
        
        if (exists($self->{'__groups'}->{$group_id})) {
                return $self->{'__groups'}->{$group_id};
        }
        
        my %data = ();
        
        my $group = $self->api_call({method => "flickr.groups.getInfo",
                                     args   => {group_id=> $group_id}});
        
        if ($group) {
                foreach my $prop ("name", "description") {
                        $data{$prop} = $group->findvalue("/rsp/group/$prop");
                }
                
                $data{id} = $group_id;
        }
        
        $self->{'__groups'}->{$group_id} = \%data;
        return $self->{'__groups'}->{$group_id};
}

=head2 $obj->collect_user_data($user_id)

Returns a hash ref of the meta data associated with a user.

If any errors are unencounter an error is recorded via the B<log>
method and the method returns undef.

=cut

sub collect_user_data {
        my $self    = shift;
        my $user_id = shift;
        
        if (exists($self->{'__users'}->{$user_id})) {
                return $self->{'__users'}->{$user_id};
        }
        
        my %data = ();
        
        my $user = $self->api_call({method => "flickr.people.getInfo",
                                    args   => {user_id=> $user_id}});
        
        if ($user) {
                
                $data{user_id} = $user_id;
                
                foreach my $prop ("username", "realname", "mbox_sha1sum") {
                        $data{$prop} = $user->findvalue("/rsp/person/$prop");
                }
        }
        
        $self->{'__users'}->{$user_id} = \%data;
        return $self->{'__users'}->{$user_id};
}

sub collect_user_data_by_screenname {
        my $self = shift;
        my $name = shift;
        
        if (exists($self->{'__screen'}->{$name})) {
                return $self->collect_user_data($self->{'__screen'}->{$name});
        }
        
        #
        
        my $user = $self->api_call({method => "flickr.people.findByUsername",
                                    args   => {username=> $name}});


        my $user_id = $user->findvalue("/rsp/user/\@id");

        #

        $self->{'__screen'}->{$name} = $user_id;
        return $self->collect_user_data($user_id);
}

=head2 $obj->collect_photoset_data($photoset_id)

Returns a hash ref of the meta data associated with a photoset.

If any errors are unencounter an error is recorded via the B<log>
method and the method returns undef.

=cut

sub collect_photoset_data {
        my $self   = shift;
        my $set_id = shift;
        
        if (exists($self->{'__sets'}->{$set_id})) {
                return $self->{'__sets'}->{$set_id};
        }
        
        my %data = ();
        
        my $set = $self->api_call({method => "flickr.photosets.getInfo",
				 args   => {photoset_id=> $set_id}});

        if ($set) {
                foreach my $prop ("title", "description") {
                        $data{$prop} = $set->findvalue("/rsp/photoset/$prop");
                }
                
                $data{user_id} = $set->findvalue("/rsp/photoset/\@owner");
                $data{id}      = $set_id;
        }
        
        $self->{'__sets'}->{$set_id} = \%data;
        return $self->{'__sets'}->{$set_id};
}

=head2 $obj->collect_cc_data()

Returns a hash ref of the Creative Commons licenses used by Flickr.

If any errors are unencounter an error is recorded via the B<log>
method and the method returns undef.

=cut

sub collect_cc_data {
        my $self = shift;
        
        if (exists($self->{'__cc'})) {
                return $self->{'__cc'};
        }
        
        my %cc = ();
        
        my $licenses = $self->api_call({"method" => "flickr.photos.licenses.getInfo"});
        
        if (! $licenses) {
                return undef;
        }
        
        foreach my $l ($licenses->findnodes("/rsp/licenses/license")) {
                $cc{ $l->getAttribute("id") } = $l->getAttribute("url");
        }
        
        $self->{'__cc'} = \%cc;
        return $self->{'__cc'};
}

=head2 $obj->collect_comment_data()

Returns a hash ref of comments made about a photo.

=cut

sub collect_comment_data {
        my $self = shift;
        my $data = shift;

        my %comments = ();

        my $list = $self->api_call({method => "flickr.photos.comments.getList",
                                    args   => {photo_id => $data->{photo_id}}});

        if ($list) {

                foreach my $c ($list->findnodes("/rsp/comments/comment")) {

                        my $permalink = $c->getAttribute("permalink");
                        my $user      = $self->collect_user_data($c->getAttribute("author"));

                        if (! exists($data->{users}->{$user->{user_id}})) {
                                $data->{users}->{$user->{user_id}} = $user;
                        }

                        my %cdata = (user_id => $user->{user_id},
                                     content => $c->string_value(),
                                     date    => $c->getAttribute("datecreate"),
                                     id      => $c->getAttribute("id"));

                        $comments{$permalink} = \%cdata;
                }
        }

        return \%comments;
}

=head2 $obj->make_photo_triples(\%data)

Returns an array ref (or alist in a wantarray context) of array refs
of the meta data associated with a photo (I<%data>).

=cut

sub make_photo_triples {
        my $self = shift;
        my $data = shift;
        
        my @triples = ();
        
        my $photo = sprintf("%s%s/%d",$FLICKR_URL_PHOTOS,$data->{user_id},$data->{photo_id});
        
        my $flickr_photo     = $DEFAULT_NS{flickr}."photo";
        my $flickr_photoset  = $DEFAULT_NS{flickr}."photoset";
        my $flickr_user      = $DEFAULT_NS{flickr}."user";
        my $flickr_tag       = $DEFAULT_NS{flickr}."tag";
        my $flickr_note      = $DEFAULT_NS{flickr}."note";
        my $flickr_comment   = $DEFAULT_NS{flickr}."comment";
        my $flickr_group     = $DEFAULT_NS{flickr}."group";
        my $flickr_grouppool = $DEFAULT_NS{flickr}."grouppool";
        
        my $dc_still_image   = $DEFAULT_NS{dcterms}."StillImage";
        my $foaf_person      = $DEFAULT_NS{foaf}."Person";
        my $skos_concept     = $DEFAULT_NS{skos}."Concept";
        my $anno_annotation  = $DEFAULT_NS{a}."Annotation";
        
        if (scalar(keys %{$data->{users}})) {
                push @triples, [$flickr_user, $self->uri_shortform("rdfs","subClassOf"), $foaf_person];
        }
        
        if (exists($data->{tags})) {
                push @triples, [$flickr_tag, $self->uri_shortform("rdfs","subClassOf"), $skos_concept];
        }
        
        if (exists($data->{notes})) {
                push @triples, [$flickr_note, $self->uri_shortform("rdfs","subClassOf"), $anno_annotation];
        }

        if (exists($data->{comments})) {
                push @triples, [$flickr_comment, $self->uri_shortform("rdfs","subClassOf"), $anno_annotation];
        }

        #
        # static files
        #

        foreach my $label (keys %{$data->{files}}) {
                
                # TO DO - make me a method
                
                my $uri = $data->{files}->{$label}->{uri};
                
                push @triples, [$uri, $self->uri_shortform("exifi", "width"), $data->{files}->{$label}->{width}];
                push @triples, [$uri, $self->uri_shortform("exifi", "height"), $data->{files}->{$label}->{height}];
                push @triples, [$uri, $self->uri_shortform("dcterms", "relation"), $label];
                push @triples, [$uri, $self->uri_shortform("rdfs", "seeAlso"), $photo];
                push @triples, [$uri, $self->uri_shortform("rdfs", "seeAlso"), "$photo#exif"];
                push @triples, [$uri, $self->uri_shortform("rdf", "type"), $self->uri_shortform("dcterms","StillImage")];
                
                if ($label ne "Original") {
                        push @triples, [$uri,$self->uri_shortform("dcterms","isVersionOf"),$data->{files}->{'Original'}->{uri}];
                }
                
        }
        
        #
        # flickr data
        #

        push @triples, [$photo, $self->uri_shortform("rdf", "type"), $self->uri_shortform("flickr","photo")];
        push @triples, [$photo, $self->uri_shortform("dc", "creator"), sprintf("%s%s",$FLICKR_URL_PEOPLE,$data->{user_id})];
        push @triples, [$photo, $self->uri_shortform("dc", "title"), $data->{title}];
        push @triples, [$photo, $self->uri_shortform("dc", "description"), $data->{desc}];
        push @triples, [$photo, $self->uri_shortform("dc", "created"), time2str("%Y-%m-%dT%H:%M:%S%z",str2time($data->{taken}))];
        push @triples, [$photo, $self->uri_shortform("dc", "dateSubmitted"), time2str("%Y-%m-%dT%H:%M:%S%z",$data->{posted})];
        push @triples, [$photo, $self->uri_shortform("acl", "accessor"), $data->{visibility}];
        push @triples, [$photo, $self->uri_shortform("acl", "access"), "visbility"];
        
        #
        # geo data
        #
        
        if (($data->{lat}) && ($data->{long})) {
                push @triples, [$photo,$self->uri_shortform("geo","lat"),$data->{lat}];
                push @triples, [$photo,$self->uri_shortform("geo","long"),$data->{long}];
                push @triples, [$photo,$self->uri_shortform("dc","coverage"),$data->{coverage}];
        }
        
        else {
                if (my $geodata = $self->geodata_from_tags($data)) {
                        push @triples, [$photo, $self->uri_shortform("geo", "lat"), $geodata->{lat}];
                        push @triples, [$photo, $self->uri_shortform("geo", "long"), $geodata->{long}];
                }
        }        

        #
        # licensing
        #
        
        if ($data->{license}) {
                push @triples, [$photo,$self->uri_shortform("cc","license"),$data->{license}];
                push @triples, ($self->make_cc_triples($data->{license}));
        }
        
        else {
                push @triples, [$photo,$self->uri_shortform("dc","rights"),$LICENSE_ALLRIGHTS];
        }
        
        #
        # tags
        #
        
        if (exists($data->{tags})) {
                
                foreach my $id (keys %{$data->{tags}}) {
                        
                        my $tag_uri = $self->build_user_tag_uri($data->{tags}->{$id});
                        push @triples, [$photo,$self->uri_shortform("dc","subject"),$tag_uri];
                        
                        push @triples, ($self->make_tag_triples($data->{tags}->{$id}));
                }
        }
        
        #
        # notes/annotations
        #
        
        if (exists($data->{notes})) {
                
                foreach my $n (@{$data->{notes}}) {
                        
                        # TO DO : how to build/make note triples without $photo
                        
                        my $note       = "$photo#note-$n->{id}";
                        my $author_uri = $self->build_user_uri($n->{author});
                        
                        push @triples, [$photo,$self->uri_shortform("a","hasAnnotation"),$note];
                        
                        push @triples, [$note,$self->uri_shortform("a","annotates"),$photo];
                        push @triples, [$note,$self->uri_shortform("a","author"),$author_uri];
                        push @triples, [$note,$self->uri_shortform("a","body"),$n->{body}];
                        push @triples, [$note,$self->uri_shortform("i","boundingBox"), "$n->{x} $n->{y} $n->{w} $n->{h}"];
                        push @triples, [$note,$self->uri_shortform("i","regionDepicts"),$data->{files}->{'Medium'}->{'uri'}];
                        push @triples, [$note,$self->uri_shortform("rdf","type"),$self->uri_shortform("flickr","note")];
                }
        }
        
        #
        # users (authors)
        #
        
        foreach my $user (keys %{$data->{users}}) {
                push @triples, ($self->make_user_triples($data->{users}->{$user}));
        }
        
        #
        # comments
        #
        
        if (exists($data->{comments})) {
                push @triples, ($self->make_comment_triples($data));
                
                foreach my $uri (keys %{$data->{comments}}) {
                        push @triples, [$photo, $self->uri_shortform("a", "hasAnnotation"), $uri] 
                }
        }
        
        #
        # EXIF data
        #
        
        # dateTimeOriginal : EXIF/36867
        # dateTimeDigitzed : EXIF/36868

        foreach my $facet (keys %{$data->{exif}}) {
                
                if (! exists($RDFMAP{$facet})) {
                        next;
                }
                
                my $photo_o_url = $data->{files}->{Original}->{uri};

                foreach my $tag (keys %{$data->{exif}->{$facet}}) {
                        
                        my $label = $RDFMAP{$facet}->{$tag};
                        
                        if (! $label) {
                                $self->log()->warning("can't find any label for $facet tag : $tag");
                                next;
                        }

                        my $value = $data->{exif}->{$facet}->{$tag};

                        # dateTimeOriginal/Digitized

                        if (($facet eq "EXIF") && (($tag == 36867) || ($tag == 36868))) {

                                my $time = str2time($value);
                                $value   = time2str("%Y-%m-%dT%H:%M:%S%Z", $time);
                        }
                        
                        push @triples, ["$photo#exif", $self->uri_shortform("exif","$label"), "$value"];
                }
        }
        
        #
        # sets
        #
        
        foreach my $set (@{$data->{sets}}) {
                
                my $set_uri = $self->build_photoset_uri($set);
                push @triples, [$photo, $self->uri_shortform("dcterms","isPartOf"),$set_uri];
                
                push @triples, ($self->make_photoset_triples($set));
        }
        
        #
        # groups
        #
        
        foreach my $group (@{$data->{groups}}) {
                
                my $pool_uri  = $self->build_grouppool_uri($group->{id});
                push @triples, [$photo, $self->uri_shortform("dcterms","isPartOf"),$pool_uri];
                
                push @triples, ($self->make_group_triples($group));
                push @triples, ($self->make_grouppool_triples($group));
        }
        
        return (wantarray) ? @triples : \@triples;
}

=head2 $obj->make_user_triples(\%user_data)

Returns an array ref (or list in a wantarray context) of array
refs of the meta data associated with a user (I<%user_data>).

=cut

sub make_user_triples {
        my $self      = shift;
        my $user_data = shift;
        
        my $uri = $self->build_user_uri($user_data->{user_id});
        
        my @triples = ();
        
        push @triples, [$uri,$self->uri_shortform("foaf","nick"),$user_data->{username}];
        push @triples, [$uri,$self->uri_shortform("foaf","name"),$user_data->{realname}];
        push @triples, [$uri,$self->uri_shortform("foaf","mbox_sha1sum"),$user_data->{mbox_sha1sum}];
        push @triples, [$uri,$self->uri_shortform("rdf","type"),$self->uri_shortform("flickr","user")];
        
        return (wantarray) ? @triples : \@triples;
}

=head2 $obj->make_tag_triples(\@tag_data)

Returns an array ref (or list in a wantarray context) of array
refs of the meta data associated with a tag (I<@tag_data>).

=cut

sub make_tag_triples {
        my $self     = shift;
        my $tag_data = shift;
        
        my $clean  = $tag_data->[0];
        my $raw    = $tag_data->[1];
        my $author = $tag_data->[2];
        
        my $author_uri = $self->build_user_uri($author);
        my $tag_uri    = $self->build_user_tag_uri($tag_data);
        my $clean_uri  = $self->build_global_tag_uri($tag_data);
        
        #
        
        my @triples = ();
        
        push @triples, [$tag_uri,$self->uri_shortform("rdf","type"),$self->uri_shortform("flickr","tag")];
        push @triples, [$tag_uri,$self->uri_shortform("skos","prefLabel"),$raw];
        
        if ($raw ne $clean) {
                push @triples, [$tag_uri,$self->uri_shortform("skos","altLabel"),$clean];
        }
        
        push @triples, [$tag_uri,$self->uri_shortform("dc","creator"),$author_uri];
        push @triples, [$tag_uri,$self->uri_shortform("dcterms","isPartOf"),$FLICKR_URL_TAGS.$clean];
        
        #
        
        push @triples, [$FLICKR_URL_TAGS.$clean,$self->uri_shortform("rdf","type"),$self->uri_shortform("flickr","tag")];
        push @triples, [$FLICKR_URL_TAGS.$clean,$self->uri_shortform("skos","prefLabel"),$clean];
        
        return (wantarray) ? @triples : \@triples;
}

=head2 $pkg->make_photoset_triples(\%set_data)

Returns an array ref (or list in a wantarray context) of array
refs of the meta data associated with a photoset (I<%set_data>).

=cut

sub make_photoset_triples {
        my $self     = shift;
        my $set_data = shift;
        
        my @triples = ();
        
        my $set_uri     = $self->build_photoset_uri($set_data);
        my $creator_uri = $self->build_user_uri($set_data->{user_id});
        
        push @triples, [$set_uri, $self->uri_shortform("dc", "title"), $set_data->{title}];
        push @triples, [$set_uri, $self->uri_shortform("dc", "description"), $set_data->{description}];
        push @triples, [$set_uri, $self->uri_shortform("dc", "creator"), $creator_uri];
        push @triples, [$set_uri, $self->uri_shortform("rdf", "type"), $self->uri_shortform("flickr","photoset")];
        
        return (wantarray) ? @triples : \@triples;
}

=head2 $obj->make_group_triples(\%group_data)

Returns an array ref (or list in a wantarray context) of array
refs of the meta data associated with a group (I<%group_data>).

=cut

sub make_group_triples {
        my $self       = shift;
        my $group_data = shift;
        
        my @triples = ();
        
        my $group_uri = $self->build_group_uri($group_data->{id});
        
        push @triples, [$group_uri,$self->uri_shortform("dc","title"),$group_data->{name}];
        push @triples, [$group_uri,$self->uri_shortform("dc","description"),$group_data->{description}];
        push @triples, [$group_uri,$self->uri_shortform("rdf","type"),$self->uri_shortform("flickr","group")];
        
        return (wantarray) ? @triples : \@triples;
}

=head2 $obj->make_grouppool_triples(\%group_data)

Returns an array ref (or list in a wantarray context) of array
refs of the meta data associated with a group pool (I<%group_data>).

=cut

sub make_grouppool_triples {
        my $self       = shift;
        my $group_data = shift;
        
        my @triples = ();
        
        my $group_uri = $self->build_group_uri($group_data->{id});
        my $pool_uri  = $self->build_grouppool_uri($group_data->{id});
        
        push @triples, [$pool_uri, $self->uri_shortform("dcterms","isPartOf"),$group_uri];
        push @triples, [$pool_uri, $self->uri_shortform("rdf","type"),$self->uri_shortform("flickr","grouppool")];
        
        return (wantarray) ? @triples : \@triples;
}

=head2 $obj->make_cc_triples($url)

Returns an array ref (or list in a wantarray context) of array
refs of the meta data associated with a Creative Commons license
(I<$url>).

=cut

sub make_cc_triples {
        my $self    = shift;
        my $license = shift;
        
        my @triples = ();
        
        $license =~ m!http://creativecommons.org/licenses/(.*)/\d\.\d/?$!;
        my $key  = $1;
        
        #
        
        if (exists($CC_PERMITS{$key})) {
                
                foreach my $type (keys %{$CC_PERMITS{$key}}) {
                        foreach my $perm (@{$CC_PERMITS{$key}->{$type}}) {
                                push @triples, [$license, $self->uri_shortform("cc",$type),$DEFAULT_NS{cc}.$perm];
                        }
                }
                
                push @triples, [$license, $self->uri_shortform("rdf","type"),$self->uri_shortform("cc","License")];
        }
        
        return (wantarray) ? @triples : \@triples;
}

=head2 $obj->make_comment_triples(\%data)

Returns an array ref (or alist in a wantarray context) of array refs
of the meta data associated with a photo comment (I<%data>).

=cut

sub make_comment_triples {
        my $self = shift;
        my $data = shift;

        my $photo_uri = $self->build_photo_uri($data);
        my @triples   = ();

        foreach my $uri_comment (keys %{$data->{comments}}) {

                my $comment    = $data->{comments}->{$uri_comment};
                my $identifier = $comment->{id};

                my $w3cdtf     = time2str("%Y-%m-%dT%H:%M:%S", $comment->{date});
                my $uri_author = $self->build_user_uri($comment->{user_id});

                #
                # Use atom:content instead of a:body ?
                #

                push @triples, [$uri_comment, $self->uri_shortform("dc", "creator"), $uri_author];
                push @triples, [$uri_comment, $self->uri_shortform("a", "body"), $data->{comments}->{$uri_comment}->{content}];
                push @triples, [$uri_comment, $self->uri_shortform("rdf", "type"), $self->uri_shortform("flickr","comment")];
                push @triples, [$uri_comment, $self->uri_shortform("dc", "created"), $w3cdtf];
                push @triples, [$uri_comment, $self->uri_shortform("dc", "identifier"), $identifier];
                push @triples, [$uri_comment, $self->uri_shortform("a", "annotates"), $photo_uri];
        }

        return (wantarray) ? @triples : \@triples;
}

=head2 $obj->geodata_from_tags(\%data)

Try to parse out geolocative data from a collection of tag data.

Returns a hash ref (containing 'lat' and 'long' keys) on success
or undef if there were no matches.

=cut

sub geodata_from_tags {
        my $self = shift;
        my $data = shift;

        my %geo = ();

        foreach my $id (keys %{$data->{tags}}) {
                my $tag_data = $data->{tags}->{$id};
                my $raw_tag  = $tag_data->[1];

                if ($raw_tag =~ m!^geo:(lat|long)=(.*)$!) {
                        $geo{$1} = $2;
                }

                if (($geo{lat}) && ($geo{long})) {
                        return \%geo;
                }
        }


        return undef;
}        

=head2 $obj->namespaces()

Returns a hash ref of the prefixes and namespaces used by I<Net::Flickr::RDF>

The default key/value pairs are :

=over 4

=item B<a>

http://www.w3.org/2000/10/annotation-ns

=item B<acl>

http://www.w3.org/2001/02/acls#

=item B<atom>

http://www.w3.org/2005/Atom/

=item B<cc>

http://web.resource.org/cc/

=item B<dc>

http://purl.org/dc/elements/1.1/

=item B<dcterms>

http://purl.org/dc/terms/

=item B<exif>

http://nwalsh.com/rdf/exif#

=item B<exifi>

http://nwalsh.com/rdf/exif-intrinsic#

=item B<flickr>

x-urn:flickr:

=item B<foaf>

http://xmlns.com/foaf/0.1/#

=item B<geo> 

http://www.w3.org/2003/01/geo/wgs84_pos#

=item B<i>

http://www.w3.org/2004/02/image-regions#

=item B<rdf>

http://www.w3.org/1999/02/22-rdf-syntax-ns#

=item B<rdfs>

http://www.w3.org/2000/01/rdf-schema#

=item B<skos>

http://www.w3.org/2004/02/skos/core#

=back

=cut

sub namespaces {
        my $self = shift;
        return (wantarray) ? %DEFAULT_NS : \%DEFAULT_NS;
}

=head2 $obj->namespace_prefix($uri)

Return the namespace prefix for I<$uri>

=cut

sub namespace_prefix {
        my $self = shift;
        my $uri  = shift;
        
        my $ns = $self->namespaces();
        
        foreach my $prefix (keys %$ns) {
                if ($ns->{$prefix} eq $uri) {
                        return $prefix;
                }
        }
    
        return undef;
}

=head2 $obj->uri_shortform($prefix,$name)

Returns a string in the form of I<prefix>:I<property>. The property is
the value of $name. The prefix passed may or may be the same as the prefix
returned depending on whether or not the user has defined or redefined their
own list of namespaces.

Unless this package is subclassed the prefix passed to the method is assumed to
be one of prefixes in the B<default> list of namespaces.

=cut

sub uri_shortform {
        my $self   = shift;
        my $prefix = shift;
        my $name   = shift;
        
        my $uri = (ref($self) eq __PACKAGE__) ? $DEFAULT_NS{$prefix} : $self->namespaces()->{$prefix};
        
        if (! $uri) {
                $self->log()->error("unable to determine URI for prefix : '$prefix'");
                return undef;
        }
        
        my $user_prefix = $self->namespace_prefix($uri);
        return join(":",$user_prefix,$name);
}

=head2 $obj->api_call(\%args)

Valid args are :

=over 4

=item * B<method>

A string containing the name of the Flickr API method you are
calling.

=item * B<args>

A hash ref containing the key value pairs you are passing to 
I<method>

=back

If the method encounters any errors calling the API, receives an API error
or can not parse the response it will log an error event, via the B<log> method,
and return undef.

Otherwise it will return a I<XML::LibXML::Document> object (if XML::LibXML is
installed) or a I<XML::XPath> object.

=cut

# Defined in Net::Flickr::API

=head2 $obj->log()

Returns a I<Log::Dispatch> object.

=cut

# Defined in Net::Flickr::API

=head2 $obj->serialise_triples(\@triples,\*$fh)

Print I<@triples> as RDF/XML to a filehandle (I<$fh>). If no filehandle
is defined, prints to STDOUT.

=cut

sub serialise_triples {
        my $self    = shift;
        my $triples = shift;
        my $fh      = shift;
        
        if (! $fh) {
                $fh = \*STDOUT;
        }
        
        #
        # IO::Scalar-ism
        #

        if ($fh->isa("IO::Scalar")) {
                $fh->binmode(":utf8");
        }

        else {
                binmode $fh, ":utf8";
        }

        #
        #
        #

        my $ser = RDF::Simple::Serialiser->new();
        
        my %ns = $self->namespaces();
        
        foreach my $prefix (keys %ns) {
                $ser->addns($prefix,$ns{$prefix});
        }
        
        $fh->print($ser->serialise(@$triples));
        return 1;
}

=head2 $obj->serialize_triples(\@triples,\*$fh)

An alias for I<serialise_triples>

=cut

sub serialize_triples {
        my $self = shift;
        $self->serialise_triples(@_);
}

=head1 VERSION

1.9

=head1 DATE

$Date: 2006/08/18 03:12:32 $

=head1 AUTHOR

Aaron Straup Cope E<lt>ascope@cpan.orgE<gt>

=head1 EXAMPLES

=head2 CONFIG FILES

This is an example of a Config::Simple file used to collect RDF data
from Flickr

 [flickr] 
 api_key=asd6234kjhdmbzcxi6e323
 api_secret=s00p3rs3k3t
 auth_token=123-omgwtf4u

=head2 RDF

This is an example of an RDF dump for a photograph backed up from Flickr :

 <?xml version='1.0'?>    
  <rdf:RDF
   xmlns:dc="http://purl.org/dc/elements/1.1/"
   xmlns:geo="http://www.w3.org/2003/01/geo/wgs84_pos#"
   xmlns:a="http://www.w3.org/2000/10/annotation-ns"
   xmlns:acl="http://www.w3.org/2001/02/acls#"
   xmlns:exif="http://nwalsh.com/rdf/exif#"
   xmlns:skos="http://www.w3.org/2004/02/skos/core#"
   xmlns:cc="http://web.resource.org/cc/"
   xmlns:foaf="http://xmlns.com/foaf/0.1/"
   xmlns:exifi="http://nwalsh.com/rdf/exif-intrinsic#"
   xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
   xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
   xmlns:flickr="x-urn:flickr:"
   xmlns:dcterms="http://purl.org/dc/terms/"
   xmlns:i="http://www.w3.org/2004/02/image-regions#"
   >

   <flickr:photo rdf:about="http://www.flickr.com/photos/35034348999@N01/30763528">
    <dc:description></dc:description>
    <geo:long>-122.417068</geo:long>
    <acl:access>visbility</acl:access>
    <geo:lat>37.7742</geo:lat>
    <dc:created>2005-08-02T18:12:19-0700</dc:created>
    <dc:title>20050802(007).jpg</dc:title>
    <acl:accessor>public</acl:accessor>
    <dc:dateSubmitted>2005-08-02T18:16:20-0700</dc:dateSubmitted>
    <cc:license rdf:resource="http://creativecommons.org/licenses/by-nd/2.0/"/>
    <dc:creator rdf:resource="http://www.flickr.com/people/35034348999@N01"/>
    <dc:subject rdf:resource="http://www.flickr.com/photos/35034348999@N01/tags/sanfrancisco"/>
    <dc:subject rdf:resource="http://www.flickr.com/photos/35034348999@N01/tags/geolat377742"/>
    <dc:subject rdf:resource="http://www.flickr.com/photos/35034348999@N01/tags/usa"/>
    <dc:subject rdf:resource="http://www.flickr.com/photos/35034348999@N01/tags/california"/>
    <dc:subject rdf:resource="http://www.flickr.com/photos/35034348999@N01/tags/geolong122417068"/>
    <dc:subject rdf:resource="http://www.flickr.com/photos/35034348999@N01/tags/cameraphone"/>
    <dc:subject rdf:resource="http://www.flickr.com/photos/35034348999@N01/tags/geotagged"/>
    <dcterms:isPartOf rdf:resource="http://www.flickr.com/photos/35034348999@N01/sets/1082058"/>
    <dcterms:isPartOf rdf:resource="http://www.flickr.com/groups/97155967@N00/pool"/>
    <a:hasAnnotation rdf:resource="http://www.flickr.com/photos/35034348999@N01/30763528#note-1140939"/>
    <a:hasAnnotation rdf:resource="http://www.flickr.com/photos/35034348999@N01/30763528#note-1140942"/>
    <a:hasAnnotation rdf:resource="http://www.flickr.com/photos/35034348999@N01/30763528#note-1140945"/>
    <a:hasAnnotation rdf:resource="http://www.flickr.com/photos/35034348999@N01/30763528#note-1140946"/>
    <a:hasAnnotation rdf:resource="http://www.flickr.com/photos/35034348999@N01/30763528#note-1140952"/>
    <a:hasAnnotation rdf:resource="http://www.flickr.com/photos/35034348999@N01/30763528#note-1142648"/>
    <a:hasAnnotation rdf:resource="http://www.flickr.com/photos/35034348999@N01/30763528#note-1142656"/>
    <a:hasAnnotation rdf:resource="http://www.flickr.com/photos/35034348999@N01/30763528#note-1143239"/>
    <a:hasAnnotation rdf:resource="http://www.flickr.com/photos/35034348999@N01/30763528#note-1148950"/>
    <a:hasAnnotation rdf:resource="http://www.flickr.com/photos/straup/30763528/#comment8400103"/>
    <a:hasAnnotation rdf:resource="http://www.flickr.com/photos/straup/30763528/#comment8399772"/>
   </flickr:photo>

   <dcterms:StillImage rdf:about="http://static.flickr.com/23/30763528_a981fab285_s.jpg">
    <dcterms:relation>Square</dcterms:relation>
    <exifi:height>75</exifi:height>
    <exifi:width>75</exifi:width>
    <dcterms:isVersionOf rdf:resource="http://static.flickr.com/23/30763528_a981fab285_o.jpg"/>
    <rdfs:seeAlso rdf:resource="http://www.flickr.com/photos/35034348999@N01/30763528"/>
    <rdfs:seeAlso rdf:resource="http://www.flickr.com/photos/35034348999@N01/30763528#exif"/>
   </dcterms:StillImage>

   <flickr:tag rdf:about="http://www.flickr.com/photos/35034348999@N01/tags/california">
    <skos:prefLabel>california</skos:prefLabel>
    <dc:creator rdf:resource="http://www.flickr.com/people/35034348999@N01"/>
    <dcterms:isPartOf rdf:resource="http://www.flickr.com/tags/california"/>
   </flickr:tag>

   <flickr:comment rdf:about="http://www.flickr.com/photos/straup/30763528/#comment8400103">
    <dc:identifier>6065-30763528-8400103</dc:identifier>
    <dc:created>2005-08-02T18:52:23</dc:created>
    <a:body>moooaahahaahahmooo</a:body>
    <dc:creator rdf:resource="http://www.flickr.com/people/44124415257@N01"/>
    <a:annotates rdf:resource="http://www.flickr.com/photos/35034348999@N01/30763528"/>
   </flickr:comment>

   <flickr:user rdf:about="http://www.flickr.com/people/44124415257@N01">
    <foaf:mbox_sha1sum>b2310525591ca71b1cb9c2e3226dec1765d76c1e</foaf:mbox_sha1sum>
    <foaf:name></foaf:name>
    <foaf:nick>karlcow</foaf:nick>
   </flickr:user>

   <flickr:note rdf:about="http://www.flickr.com/photos/35034348999@N01/30763528#note-1140939">
    <i:boundingBox>326 181 97 25</i:boundingBox>
    <a:body>Did you see that this shirt makes me a beautiful breast?</a:body>
    <i:regionDepicts rdf:resource="http://static.flickr.com/23/30763528_a981fab285.jpg"/>
    <a:author rdf:resource="http://www.flickr.com/people/44124415257@N01"/>
    <a:annotates rdf:resource="http://www.flickr.com/photos/35034348999@N01/30763528"/>
   </flickr:note>

   <flickr:note rdf:about="http://www.flickr.com/photos/35034348999@N01/30763528#note-1140952">
    <i:boundingBox>9 205 145 55</i:boundingBox>
    <a:body>Do you want my opinion? There's a love affair going on here… Anyway. Talking non sense. We all know Heather is committed to Flickr. She even only dresses at FlickrApparel. Did they say &amp;quot;No Logo&amp;quot;. Doh Dude.</a:body>
    <i:regionDepicts rdf:resource="http://static.flickr.com/23/30763528_a981fab285.jpg"/>
    <a:author rdf:resource="http://www.flickr.com/people/44124415257@N01"/>
    <a:annotates rdf:resource="http://www.flickr.com/photos/35034348999@N01/30763528"/>

   </flickr:note>

   <flickr:photoset rdf:about="http://www.flickr.com/photos/35034348999@N01/sets/1082058">
    <dc:description></dc:description>
    <dc:title>Flickr</dc:title>
    <dc:creator rdf:resource="http://www.flickr.com/people/35034348999@N01"/>
   </flickr:photoset>

   <flickr:user rdf:about="http://www.flickr.com/people/34427469121@N01">
    <foaf:mbox_sha1sum>00d5b413e52b4d7d35dc982102c49e930a0ef631</foaf:mbox_sha1sum>
    <foaf:name>George Oates</foaf:name>
    <foaf:nick>George</foaf:nick>
   </flickr:user>

   <flickr:note rdf:about="http://www.flickr.com/photos/35034348999@N01/30763528#note-1140946">
    <i:boundingBox>355 31 103 95</i:boundingBox>
    <a:body>(Yes… I love you heather, you are my dream star)</a:body>
    <i:regionDepicts rdf:resource="http://static.flickr.com/23/30763528_a981fab285.jpg"/>
    <a:author rdf:resource="http://www.flickr.com/people/44124415257@N01"/>
    <a:annotates rdf:resource="http://www.flickr.com/photos/35034348999@N01/30763528"/>
   </flickr:note>

   <rdf:Description rdf:about="x-urn:flickr:tag">
    <rdfs:subClassOf rdf:resource="http://www.w3.org/2004/02/skos/core#Concept"/>
   </rdf:Description>

   <flickr:tag rdf:about="http://www.flickr.com/tags/usa">
    <skos:prefLabel>usa</skos:prefLabel>
   </flickr:tag>

   <flickr:tag rdf:about="http://www.flickr.com/tags/california">
    <skos:prefLabel>california</skos:prefLabel>
   </flickr:tag>

   <flickr:tag rdf:about="http://www.flickr.com/photos/35034348999@N01/tags/geotagged">
    <skos:prefLabel>geotagged</skos:prefLabel>
    <dc:creator rdf:resource="http://www.flickr.com/people/35034348999@N01"/>
    <dcterms:isPartOf rdf:resource="http://www.flickr.com/tags/geotagged"/>
   </flickr:tag>

   <flickr:tag rdf:about="http://www.flickr.com/photos/35034348999@N01/tags/sanfrancisco">
    <skos:prefLabel>san francisco</skos:prefLabel>
    <skos:altLabel>sanfrancisco</skos:altLabel>
    <dc:creator rdf:resource="http://www.flickr.com/people/35034348999@N01"/>
    <dcterms:isPartOf rdf:resource="http://www.flickr.com/tags/sanfrancisco"/>
   </flickr:tag>

   <flickr:user rdf:about="http://www.flickr.com/people/32373682187@N01">
    <foaf:mbox_sha1sum>479d12dec2090705278d8b2af2c50ac2c46b94d4</foaf:mbox_sha1sum>
    <foaf:name>heather powazek champ</foaf:name>
    <foaf:nick>heather</foaf:nick>
   </flickr:user>

   <flickr:tag rdf:about="http://www.flickr.com/tags/geotagged">
    <skos:prefLabel>geotagged</skos:prefLabel>
   </flickr:tag>

   <dcterms:StillImage rdf:about="http://static.flickr.com/23/30763528_a981fab285.jpg">
    <dcterms:relation>Medium</dcterms:relation>
    <exifi:height>375</exifi:height>
    <exifi:width>500</exifi:width>
    <dcterms:isVersionOf rdf:resource="http://static.flickr.com/23/30763528_a981fab285_o.jpg"/>
    <rdfs:seeAlso rdf:resource="http://www.flickr.com/photos/35034348999@N01/30763528"/>
    <rdfs:seeAlso rdf:resource="http://www.flickr.com/photos/35034348999@N01/30763528#exif"/>
   </dcterms:StillImage>

   <flickr:tag rdf:about="http://www.flickr.com/photos/35034348999@N01/tags/geolat377742">
    <skos:altLabel>geolat377742</skos:altLabel>
    <dc:creator rdf:resource="http://www.flickr.com/people/35034348999@N01"/>
    <skos:prefLabel rdf:resource="geo:lat=37.7742"/>
    <dcterms:isPartOf rdf:resource="http://www.flickr.com/tags/geolat377742"/>
   </flickr:tag>

   <flickr:note rdf:about="http://www.flickr.com/photos/35034348999@N01/30763528#note-1142648">
    <i:boundingBox>202 224 50 50</i:boundingBox>
    <a:body>dude! who did this?</a:body>
    <i:regionDepicts rdf:resource="http://static.flickr.com/23/30763528_a981fab285.jpg"/>
    <a:author rdf:resource="http://www.flickr.com/people/32373682187@N01"/>
    <a:annotates rdf:resource="http://www.flickr.com/photos/35034348999@N01/30763528"/>
   </flickr:note>

   <flickr:tag rdf:about="http://www.flickr.com/photos/35034348999@N01/tags/cameraphone">
    <skos:prefLabel>cameraphone</skos:prefLabel>
    <dc:creator rdf:resource="http://www.flickr.com/people/35034348999@N01"/>
    <dcterms:isPartOf rdf:resource="http://www.flickr.com/tags/cameraphone"/>
   </flickr:tag>

   <flickr:user rdf:about="http://www.flickr.com/people/35034348999@N01">
    <foaf:mbox_sha1sum>a4d1b5e38db5e2ed4f847f9f09fd51cf59bc0d3f</foaf:mbox_sha1sum>
    <foaf:name>Aaron Straup Cope</foaf:name>
    <foaf:nick>straup</foaf:nick>
   </flickr:user>

   <rdf:Description rdf:about="x-urn:flickr:comment">
    <rdfs:subClassOf rdf:resource="http://www.w3.org/2000/10/annotation-nsAnnotation"/>
   </rdf:Description>

   <flickr:note rdf:about="http://www.flickr.com/photos/35034348999@N01/30763528#note-1140942">
    <i:boundingBox>468 141 22 26</i:boundingBox>
    <a:body>*sigh*</a:body>
    <i:regionDepicts rdf:resource="http://static.flickr.com/23/30763528_a981fab285.jpg"/>
    <a:author rdf:resource="http://www.flickr.com/people/44124415257@N01"/>
    <a:annotates rdf:resource="http://www.flickr.com/photos/35034348999@N01/30763528"/>
   </flickr:note>

   <flickr:tag rdf:about="http://www.flickr.com/photos/35034348999@N01/tags/usa">
    <skos:prefLabel>usa</skos:prefLabel>
    <dc:creator rdf:resource="http://www.flickr.com/people/35034348999@N01"/>
    <dcterms:isPartOf rdf:resource="http://www.flickr.com/tags/usa"/>
   </flickr:tag>

   <flickr:tag rdf:about="http://www.flickr.com/tags/cameraphone">
    <skos:prefLabel>cameraphone</skos:prefLabel>
   </flickr:tag>

   <rdf:Description rdf:about="http://www.flickr.com/photos/35034348999@N01/30763528#exif">
    <exif:flash>32</exif:flash>
    <exif:digitalZoomRatio>100/100</exif:digitalZoomRatio>
    <exif:isoSpeedRatings>1250</exif:isoSpeedRatings>
    <exif:pixelXDimension>1280</exif:pixelXDimension>
    <exif:apertureValue>336/100</exif:apertureValue>
    <exif:pixelYDimension>960</exif:pixelYDimension>
    <exif:focalLength>4.5 mm</exif:focalLength>
    <exif:dateTimeDigitized>2005-08-02T18:12:19PDT</exif:dateTimeDigitized>
    <exif:colorSpace>sRGB</exif:colorSpace>
    <exif:fNumber>f/3.2</exif:fNumber>
    <exif:dateTimeOriginal>2005-08-02T18:12:19PDT</exif:dateTimeOriginal>
    <exif:shutterSpeedValue>4321/1000</exif:shutterSpeedValue>
    <exif:exposureTime>0.05 sec (263/5260)</exif:exposureTime>
    <exif:gainControl>High gain up</exif:gainControl>
   </rdf:Description>

   <flickr:note rdf:about="http://www.flickr.com/photos/35034348999@N01/30763528#note-1142656">
    <i:boundingBox>357 193 81 28</i:boundingBox>
    <a:body>eww!</a:body>
    <i:regionDepicts rdf:resource="http://static.flickr.com/23/30763528_a981fab285.jpg"/>
    <a:author rdf:resource="http://www.flickr.com/people/32373682187@N01"/>
    <a:annotates rdf:resource="http://www.flickr.com/photos/35034348999@N01/30763528"/>
   </flickr:note>

   <flickr:tag rdf:about="http://www.flickr.com/tags/sanfrancisco">
    <skos:prefLabel>sanfrancisco</skos:prefLabel>
   </flickr:tag>

   <flickr:comment rdf:about="http://www.flickr.com/photos/straup/30763528/#comment8399772">
    <dc:identifier>6065-30763528-8399772</dc:identifier>
    <dc:created>2005-08-02T18:44:52</dc:created>
    <a:body>&amp;quot;you have been note-spammed by a passing mad cow...&amp;quot;
:)</a:body>
    <dc:creator rdf:resource="http://www.flickr.com/people/32373689382@N01"/>
    <a:annotates rdf:resource="http://www.flickr.com/photos/35034348999@N01/30763528"/>
   </flickr:comment>

   <dcterms:StillImage rdf:about="http://static.flickr.com/23/30763528_a981fab285_m.jpg">
    <dcterms:relation>Small</dcterms:relation>
    <exifi:height>180</exifi:height>
    <exifi:width>240</exifi:width>
    <dcterms:isVersionOf rdf:resource="http://static.flickr.com/23/30763528_a981fab285_o.jpg"/>
    <rdfs:seeAlso rdf:resource="http://www.flickr.com/photos/35034348999@N01/30763528"/>
    <rdfs:seeAlso rdf:resource="http://www.flickr.com/photos/35034348999@N01/30763528#exif"/>
   </dcterms:StillImage>

   <flickr:tag rdf:about="http://www.flickr.com/tags/geolong122417068">
    <skos:prefLabel>geolong122417068</skos:prefLabel>
   </flickr:tag>

   <flickr:note rdf:about="http://www.flickr.com/photos/35034348999@N01/30763528#note-1143239">
    <i:boundingBox>184 164 50 50</i:boundingBox>
    <a:body>Baaaaarp!</a:body>
    <i:regionDepicts rdf:resource="http://static.flickr.com/23/30763528_a981fab285.jpg"/>
    <a:author rdf:resource="http://www.flickr.com/people/34427469121@N01"/>
    <a:annotates rdf:resource="http://www.flickr.com/photos/35034348999@N01/30763528"/>
   </flickr:note>

   <dcterms:StillImage rdf:about="http://static.flickr.com/23/30763528_a981fab285_t.jpg">
    <dcterms:relation>Thumbnail</dcterms:relation>
    <exifi:height>75</exifi:height>
    <exifi:width>100</exifi:width>
    <dcterms:isVersionOf rdf:resource="http://static.flickr.com/23/30763528_a981fab285_o.jpg"/>
    <rdfs:seeAlso rdf:resource="http://www.flickr.com/photos/35034348999@N01/30763528"/>
    <rdfs:seeAlso rdf:resource="http://www.flickr.com/photos/35034348999@N01/30763528#exif"/>
   </dcterms:StillImage>

   <flickr:note rdf:about="http://www.flickr.com/photos/35034348999@N01/30763528#note-1140945">
    <i:boundingBox>433 103 50 50</i:boundingBox>
    <a:body>(fuck… fuck…)</a:body>
    <i:regionDepicts rdf:resource="http://static.flickr.com/23/30763528_a981fab285.jpg"/>
    <a:author rdf:resource="http://www.flickr.com/people/44124415257@N01"/>
    <a:annotates rdf:resource="http://www.flickr.com/photos/35034348999@N01/30763528"/>
   </flickr:note>

   <rdf:Description rdf:about="x-urn:flickr:user">
    <rdfs:subClassOf rdf:resource="http://xmlns.com/foaf/0.1/Person"/>
   </rdf:Description>

   <flickr:grouppool rdf:about="http://www.flickr.com/groups/97155967@N00/pool">
    <dcterms:isPartOf rdf:resource="http://www.flickr.com/groups/97155967@N00"/>
   </flickr:grouppool>

   <flickr:user rdf:about="http://www.flickr.com/people/32373689382@N01">
    <foaf:mbox_sha1sum>e0d207bb5643d4d7dd60e72d4ce2a94bae0e13b6</foaf:mbox_sha1sum>
    <foaf:name>Boris Anthony</foaf:name>
    <foaf:nick>bopuc</foaf:nick>
   </flickr:user>

   <flickr:tag rdf:about="http://www.flickr.com/photos/35034348999@N01/tags/geolong122417068">
    <skos:altLabel>geolong122417068</skos:altLabel>
    <dc:creator rdf:resource="http://www.flickr.com/people/35034348999@N01"/>
    <skos:prefLabel rdf:resource="geo:long=-122.417068"/>
    <dcterms:isPartOf rdf:resource="http://www.flickr.com/tags/geolong122417068"/>
   </flickr:tag>

   <flickr:group rdf:about="http://www.flickr.com/groups/97155967@N00">
    <dc:description></dc:description>
    <dc:title>aaronland</dc:title>
   </flickr:group>

   <flickr:tag rdf:about="http://www.flickr.com/tags/geolat377742">
    <skos:prefLabel>geolat377742</skos:prefLabel>
   </flickr:tag>

   <cc:License rdf:about="http://creativecommons.org/licenses/by-nd/2.0/">
    <cc:requires rdf:resource="http://web.resource.org/cc/Notice"/>
    <cc:requires rdf:resource="http://web.resource.org/cc/Attribution"/>
    <cc:requires rdf:resource="http://web.resource.org/cc/ShareAlike"/>
    <cc:permits rdf:resource="http://web.resource.org/cc/Reproduction"/>
    <cc:permits rdf:resource="http://web.resource.org/cc/Distribution"/>
   </cc:License>

   <dcterms:StillImage rdf:about="http://static.flickr.com/23/30763528_a981fab285_o.jpg">
    <dcterms:relation>Original</dcterms:relation>
    <exifi:height>960</exifi:height>
    <exifi:width>1280</exifi:width>
    <rdfs:seeAlso rdf:resource="http://www.flickr.com/photos/35034348999@N01/30763528"/>
    <rdfs:seeAlso rdf:resource="http://www.flickr.com/photos/35034348999@N01/30763528#exif"/>
   </dcterms:StillImage>

   <rdf:Description rdf:about="x-urn:flickr:note">
    <rdfs:subClassOf rdf:resource="http://www.w3.org/2000/10/annotation-nsAnnotation"/>
   </rdf:Description>

   <flickr:note rdf:about="http://www.flickr.com/photos/35034348999@N01/30763528#note-1148950">
    <i:boundingBox>342 197 28 33</i:boundingBox>
    <a:body>Is that just one big boob, or...?</a:body>
    <i:regionDepicts rdf:resource="http://static.flickr.com/23/30763528_a981fab285.jpg"/>
    <a:author rdf:resource="http://www.flickr.com/people/34427469121@N01"/>
    <a:annotates rdf:resource="http://www.flickr.com/photos/35034348999@N01/30763528"/>
   </flickr:note>
  </rdf:RDF>

=head1 SEE ALSO

L<Net::Flickr::API>

L<RDF::Simple>

=head1 TO DO

=over 4

=item *

Methods for describing more than just a photo; groups, tags, etc.

=item *

Update bounding boxes to be relative to individual images

=item *

Proper tests

=back

Patches are welcome.

=head1 BUGS

Please report all bugs via http://rt.cpan.org/

=head1 LICENSE

Copyright (c) 2005-2006 Aaron Straup Cope. All Rights Reserved.

This is free software. You may redistribute it and/or
modify it under the same terms as Perl itself.

=cut

return 1;

__END__
