# Copyright 2003 by Prasad Poruporuthan
# All rights reserved.
#
# This library is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
 
package X12::Parser::Cf;

#use 5.006;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use X12::Parser::Cf ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);
our $VERSION = '0.02';

# Preloaded methods go here.
my $level = 0;

#--- Cf::new
sub new {
	my $self = {};

	my @LOOPTREE;
	my %SEGMENTSTART;
	my @array;
	my @loop;

	$self->{looptree}  = \@LOOPTREE;
	$self->{segmentstart} = \%SEGMENTSTART;
	$self->{array}     = \@array;
	$self->{loop}      = \@loop;

	bless($self);
	return $self;
}
 
#--- Cf::load
sub load {
	my ($self, $file) = @_;

	open(FILE, "$file") || die "error: cannot open cf file $file\n";
	@{$self->{array}} = <FILE>;
	chop(@{$self->{array}});
	close(FILE);

	$self->_find_LOOPS();
	$self->_parse_loops();

	$self->{array} = ();
	$self->{loop} = ();
}

#--- Cf::_find_LOOPS
#--- local
sub _find_LOOPS {
	my $self = shift;
	for (my $i=0; $i<@{$self->{array}}; $i++) {
		if ( ${$self->{array}}[$i] eq "[LOOPS]" ) {
		LABEL_A:
			$i++;
			if ( ${$self->{array}}[$i] =~ /^\n/  || ${$self->{array}}[$i] =~ /^#/ ||
				${$self->{array}}[$i] =~ /^\[/ ) {
				last;
			}
			else {
				push( @{$self->{loop}}, ${$self->{array}}[$i]);
				goto LABEL_A;
			}
		}
	}
}

#--- local Cf::_parse_loops
#--- local
sub _parse_loops {
	my $self = shift;
	foreach my $loop (@{$self->{loop}}) {
		$level = 0;
		$self->_parse_loop ($loop);
	}
	foreach my $loop (@{$self->{loop}}) {
		$self->_parse_segment ($loop);
	}
}

#--- local Cf::_parse_loop
#--- local
sub _parse_loop {
	my $self = shift;
	my $loop = shift;

	$level++;

	for (my $i=0; $i<@{$self->{array}}; $i++) {
		if ( ${$self->{array}}[$i] eq "[$loop]" ) {
			push ( @{$self->{looptree}}, [ $level, $loop ] );
			LABEL_C:
			$i++;
			if ( ${$self->{array}}[$i] =~ /^segment=/ ) {
				goto LABEL_C;
			}
			if ( ${$self->{array}}[$i] =~ /^loop=/ ) {
				my @temp = split ( /=/, ${$self->{array}}[$i] );
				$self->_parse_loop ($temp[1], $level);
				$level--;
				goto LABEL_C;
			}
			else {
				return;
			}
		}
	}
}

#--- local Cf::_segment
#--- local
sub _parse_segment {
	my $self = shift;
	my $loop = shift;
	for (my $i=0; $i<@{$self->{array}}; $i++) {
		if ( ${$self->{array}}[$i] eq "[$loop]" ) {
			LABEL_B:
			$i++;
			if ( ${$self->{array}}[$i] =~ /^segment=/ ) {
				my @temp  = split ( /=/, ${$self->{array}}[$i] );
				push ( @{$self->{segmentstart}->{$loop}}, $temp[1] );
				goto LABEL_B;
			}
			elsif ( ${$self->{array}}[$i] =~ /^loop=/ ) {
				my @temp = split ( /=/, ${$self->{array}}[$i] );
				$self->_parse_segment ($temp[1]);
				goto LABEL_B;
			}
			else {
				return;
			}
		}
	}
}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

X12::Parser::Cf - Perl module for reading X12 configuration files. 

=head1 SYNOPSIS

use X12::Parser::Cf;

#-- create a X12::Parser::Cf object
 my $cf = new X12::Parser::Cf;

#-- read/load a cf file
 $cf->load ('837_004010X098.cf');

=head1 DESCRIPTION

X12::Parser::Cf module is created to read the configuration files that 
are created for parsing X12 transaction files. This module is used in
the X12::Parser module and is not designed for independent usage.

Note that this module does not do syntax checking of the configuration 
file. The user should ensure that he has got the cf file correct.

Read the X12::Parser::Readme man page for details.

The sample cf files provided with this package are good to the best of
the authors knowledge. However the user should ensure the validity of
these files. The user may use them as is at his own risk.


=head1 AUTHOR

Prasad Poruporuthan, E<lt>pprasadb@planet-save.com<gt>

=head1 SEE ALSO

I<X12::Parser>, I<X12::Parser::Readme>

=head1 COPYRIGHT AND LICENSE

Copyright 2003 by Prasad Poruporuthan

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
