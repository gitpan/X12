# Copyright 2009 by Prasad Balan
# All rights reserved.
#
# This library is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
package X12::Parser;
use strict;
require Exporter;
our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
# This allows declaration    use X12 ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = (
	'all' => [
		qw(
		  )
	]
);
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT    = qw(
);
our $VERSION = '0.50';

# Preloaded methods go here.
use X12::Parser::Tree;
use X12::Parser::Cf;

#constructor.
sub new {
	my $self = {
		file                  => undef,
		conf                  => undef,
		_TREE_ROOT            => undef,
		_TREE_POS             => undef,
		_FILE_HANDLE          => undef,
		_SEGMENT_SEPARATOR    => undef,
		_ELEMENT_SEPARATOR    => undef,
		_SUBELEMENT_SEPARATOR => undef,
		_NEXT_LOOP            => undef,
		_NEXT_SEGMENT         => undef,
	};
	return bless $self;
}

#public method, takes the X12 and Cf file name as input.
#loads the config file and sets the separators.
sub parse {
	my $self = shift;
	$self->parse_file(@_);
}

#public method, takes the X12 and Cf file name as input.
#loads the config file and sets the separators.
sub parse_file {
	my $self   = shift;
	my %params = @_;
	$self->{file} = $params{file};
	$self->{conf} = $params{conf};

	#read the config file to create the TREE object
	my $cf = X12::Parser::Cf->new();
	$self->{_TREE_ROOT} = $cf->load( file => "$self->{conf}" )
	  if defined $self->{conf};
	$self->{_TREE_POS} = $self->{_TREE_ROOT};
	if ( defined $self->{_FILE_HANDLE} ) {
		close( $self->{_FILE_HANDLE} );
	}
	open( $self->{_FILE_HANDLE}, "$self->{file}" )
	  || die "error: cannot open file $self->{file}\n";

	#set the separators
	$self->_set_separator;
}

#private method. sets the separators.
sub _set_separator {
	my $self = shift;
	my $isa  = undef;
	if ( read( $self->{_FILE_HANDLE}, $isa, 108 ) != 108 ) {
		close( $self->{_FILE_HANDLE} );
		die "error: invalid file format $self->{file}\n";
	}
	my $terminator = substr( $isa, 106, 2 );
	if ( $terminator =~ /\r\n/ ) {
		$self->{_SEGMENT_SEPARATOR} = substr( $isa, 105, 3 );
	}
	elsif ( $terminator =~ /^\n/ ) {
		$self->{_SEGMENT_SEPARATOR} = substr( $isa, 105, 2 );
	}
	else {
		$self->{_SEGMENT_SEPARATOR} = substr( $isa, 105, 1 );
	}
	$self->{_ELEMENT_SEPARATOR}    = substr( $isa, 3,   1 );
	$self->{_SUBELEMENT_SEPARATOR} = substr( $isa, 104, 1 );
	seek( $self->{_FILE_HANDLE}, -108, 1 );
}

#public method. gets the next loop.
sub get_next_loop {
	my $self = shift;
	if ( defined $self->{_NEXT_LOOP} ) {
		my $loop = $self->{_NEXT_LOOP};
		$self->{_NEXT_LOOP} = undef;
		return $loop;
	}
	else {
		return $self->_get_next_loop();
	}
}

sub get_next_pos_loop {
	my $self = shift;
	my $loop = undef;
	if ( defined $self->{_NEXT_LOOP} ) {
		$loop = $self->{_NEXT_LOOP};
		$self->{_NEXT_LOOP} = undef;
		return ( $., $loop );
	}
	else {
		$loop = $self->_get_next_loop();
		return ( $., $loop );
	}
}

sub get_next_pos_level_loop {
	my $self = shift;
	my $loop = undef;
	if ( defined $self->{_NEXT_LOOP} ) {
		$loop = $self->{_NEXT_LOOP};
		$self->{_NEXT_LOOP} = undef;
		return ( $., $self->{_TREE_POS}->get_depth(), $loop );
	}
	else {
		$loop = $self->_get_next_loop();
		return ( $., $self->{_TREE_POS}->get_depth(), $loop );
	}
}

#private method. does the hard lifting.
sub _get_next_loop {
	my $self = shift;
	my ( $segment, $file_handle, $node, $loop, @element );
	local $/;
	$/             = $self->{_SEGMENT_SEPARATOR};
	$file_handle   = $self->{_FILE_HANDLE};
	$node          = $self->{_TREE_POS};
	$self->{_LOOP} = [];
	if ( defined $self->{_LAST_SEGMENT} ) {
		push( @{ $self->{_LOOP} }, $self->{_LAST_SEGMENT} );
		$self->{_LAST_SEGMENT} = undef;
	}
	while ( $segment = <$file_handle> ) {
		chomp($segment);
		@element = split( /\Q$self->{_ELEMENT_SEPARATOR}\E/, $segment );
		$loop = $self->_check_child_match( $node, \@element );
		if ( defined $loop ) {
			$self->{_LAST_SEGMENT} = $segment;
			return $loop;
		}
		$loop = $self->_check_parent_match( $node, \@element );
		if ( defined $loop ) {
			$self->{_LAST_SEGMENT} = $segment;
			return $loop;
		}
		push( @{ $self->{_LOOP} }, $segment );
	}
	close($file_handle);
	return undef;
}

#private method. check if any of the child loops match
sub _check_child_match {
	my ( $self, $node, $elements ) = @_;
	for ( my $i = 0 ; $i < $node->get_child_count() ; $i++ ) {
		my $child = $node->get_child($i);
		if ( $child->is_loop_start($elements) ) {
			$self->{_TREE_POS} = $child;
			return $child->get_name();
		}
	}
	return undef;
}

#private method. check if any of the parent loops match
sub _check_parent_match {
	my ( $self, $node, $elements ) = @_;
	my $parent = $node->get_parent();
	if ( !defined $parent ) { return undef; }
	for ( my $i = 0 ; $i < $parent->get_child_count() ; $i++ ) {
		my $child = $parent->get_child($i);
		if ( $child->is_loop_start($elements) ) {
			$self->{_TREE_POS} = $child;
			return $child->get_name();
		}
	}
	$self->_check_parent_match( $parent, $elements );
}

#get the segments in the loop
sub get_loop_segments {
	my $self = shift;
	my $loop = $self->_get_next_loop();
	$self->{_NEXT_LOOP} = $loop;
	return @{ $self->{_LOOP} };
}

sub get_segment_separator {
	my $self = shift;
	return $self->{_SEGMENT_SEPARATOR};
}

sub get_element_separator {
	my $self = shift;
	return $self->{_ELEMENT_SEPARATOR};
}

sub get_subelement_separator {
	my $self = shift;
	return $self->{_SUBELEMENT_SEPARATOR};
}

sub print_tree {
	my $self = shift;
	my ( $pad, $index, $segment );
	my $pos = $. + 1;
	while ( my $loop = $self->get_next_loop ) {
		$pad = '  |' x $self->{_TREE_POS}->get_depth();
		print "       $pad--$loop\n";
		$pad = '  |' x ( $self->{_TREE_POS}->get_depth() + 1 );
		my @loop = $self->get_loop_segments;
		foreach $segment (@loop) {
			$index = sprintf( "%+7s", $pos++ );
			print "$index$pad-- $segment\n";
		}
	}
}
1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

X12::Parser - Perl module for parsing X12 Transaction files

=head1 SYNOPSIS

  use X12::Parser;

  # Create a parser object
  my $p = new X12::Parser;

  # Parse a file with the transaction specific configuration file
  $p->parse_file ( file => '837.txt',
              conf => 'X12-837P.cf' 
            );

  # Step through the file 
  while ( my $loop = $p->get_next_loop ) {
    my @loop = $p->get_loop_segments; 
  }

  # or use this method instead 
  while ( my ($pos, $loop) = $p->get_next_pos_loop ) { 
    my @loop = $p->get_loop_segments; 
  }

  # or use
  while ( my ($pos, $level, $loop) = $p->get_next_pos_level_loop ) {
    my @loop = $p->get_loop_segments; 
  }


=head1 ABSTRACT

X12::Parser package provides a efficient way to parse X12
transaction files. Although this package is built keeping HIPAA
related X12 transactions in mind, it is flexible and can be
adapted to parse any X12 or similar transactions.

=head1 DESCRIPTION

The X12::Parser is a token based parser for parsing X12
transaction files. The parsing of transaction files requires
the presence of configuration files for the different transaction
types.

The following methods are available:

$p = new X12::Parser;
   This is the object constructor method. It does not take any
   arguments. It only initializes the members variables required
   for parsing the transaction file.

$p->parse_file(file => '837.txt', conf => 'X12-837P.cf'); (*recommended)
$p->parse(file => '837.txt', conf => 'X12-837P.cf');
   This method takes two arguments. The first argument is the 
   transaction file that needs to be parsed. The second argument 
   specifies the configuration file to be used for parsing the 
   transaction file. 

   This package is a generic parser for parsing files that use a
   format similar to the X12 specification. The ability to parse
   different transaction types is provided by means of using different
   configuration files. The configuration files for all the X12 HIPAA
   transactions are provided with this package.

   To create your own configuration file read the X12::Parser::Readme 
   man page.

$p->get_next_loop;
   This function returns the name of the next loop that is present
   in the file being parsed. The loop name is as specified in the cf
   file.

$p->get_loop_segments;
   This function returns the segments in the loop that was returned
   by get_next_loop(). This function is to be used in tandem with 
   the get_next_loop. If not it may return/produce undesired results. 

$p->get_next_pos_loop;
   This function returns the next loop name and the segment position.
   Note position 1 corresponds to the first segment. 

$p->get_next_pos_level_loop;
   Same as get_next_pos_loop() except that in addition this function
   returns the level of the loop. The level corresponds to the level
   of the loop in the loop hierarchy. The top level loop has level 1.

$p->print_tree;
   Prints the transaction file in a tree format.

$p->get_segment_separator;
   Get the segment separator.

$p->get_element_separator;
   Get the element separator.

$p->get_subelement_separator;
   Get the sub-element separator.
   
The configuration files provided with this package and the corresponding
transaction type is mentioned below. These are the X12 HIPAA transactions.

            type    configuration file
            ----    ------------------    
        1)   270    270_004010X092.cf
        2)   271    271_004010X092.cf
        3)   276    276_004010X093.cf
        4)   277    277_004010X092.cf
        5)   278    278_004010X094_Req.cf
        6)   278    278_004010X094_Res.cf
        7)   820    820_004010X061.cf
        8)   834    834_004010X095.cf
        9)   835    835_004010X091.cf
        10)  837I   837_004010X096.cf
        11)  837D   837_004010X097.cf
        12)  837P   837_004010X098.cf

These cf files are installed in under the X12/Parser/cf folder.

The sample cf files provided with this package are good to the best of
the authors knowledge. However the user should ensure the validity of
these files. The user may use them as is at their own risk.

=head2 EXPORT

None by default.


=head1 SEE ALSO

o For details on Transaction sets refer to:
National Electronic Data Interchange Transaction Set Implementation 
Guide. Implementation guides are available for all the Transaction sets.

o I<X12::Parser::Readme> for more information on the Parser and 
  configuration files.

o I<X12::Parser::Cf>

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

Prasad Balan, I<prasad@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright 2009 by Prasad Balan

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
