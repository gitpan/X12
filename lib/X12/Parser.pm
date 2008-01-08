# Copyright 2003 by Prasad Poruporuthan
# All rights reserved.
# 
# This library is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.

package X12::Parser;

#use 5.008;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration    use X12 ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
    
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
    
);

our $VERSION = '0.09';

# Preloaded methods go here.
use X12::Parser::Cf;

sub new {
    my $self = {
        file               => undef,
        conf               => undef,
        _LINE_COUNT        => undef,
        _CURRENT_LEVEL     => undef,
        _TRACK_LEVEL       => undef,
        _ELEMENT_SEPERATOR => undef,
        _SEGMENT_SEPERATOR => undef,
        _CF                => undef,
        _FILE_HANDLE       => undef,
        _LAST_READ_SEGMENT => undef,
        _LAST_READ_LOOP    => undef,
        _ARRAY_OF_HANDLES  => undef,
    };
    return bless $self;
}


sub parse {
    my $self = shift;
    my %params = @_;
    $self->{file} = $params{file};
    $self->{conf} = $params{conf};

    # initialize in case the parse method is called again
    $self->{_LINE_COUNT} = 0,  
    $self->{_CURRENT_LEVEL} = undef,
    $self->{_TRACK_LEVEL} = undef,
    $self->{_ELEMENT_SEPERATOR} = undef,
    $self->{_SEGMENT_SEPERATOR} = undef,
    $self->{_CF} = undef,      
    $self->{_FILE_HANDLE} = undef,
    $self->{_LAST_READ_SEGMENT} = undef,
    $self->{_LAST_READ_LOOP} = undef,
    $self->{_ARRAY_OF_HANDLES} = undef,
        
    $self->{_CF}  = new X12::Parser::Cf;
    $self->{_CF}->load ("$self->{conf}") if defined $self->{conf};
    
    $self->{_TRACK_LEVEL} = 1;
    my @level_one = $self->{_CF}->get_level_one;
    unshift ( @{$self->{_ARRAY_OF_HANDLES}}, \@level_one );

    open ($self->{_FILE_HANDLE}, "$self->{file}") || die "error: cannot open file $self->{file}\n";
    $self->_set_seperator;
}


sub _set_seperator {
    my $self = shift;
    my $isa  = undef;

    if ( read($self->{_FILE_HANDLE}, $isa, 106) != 106 ) {
        close ($self->{_FILE_HANDLE});
        die "error: invalid file format $self->{file}\n";
    }
    seek ($self->{_FILE_HANDLE}, -106, 1);

    $self->{_SEGMENT_SEPERATOR} = substr ($isa, 105, 1);
    $self->{_ELEMENT_SEPERATOR} = substr ($isa, 3, 1);
}


sub get_segment_seperator {
    my $self = shift;
    return $self->{_SEGMENT_SEPERATOR};
}


sub get_element_seperator {
    my $self = shift;
    return $self->{_ELEMENT_SEPERATOR};
}


sub _parse_loop_start {
    my $self = shift;
    my ($current_loop, $segment, @segment );

    if ( defined $self->{_LAST_READ_LOOP} ) {
            my $temp = $self->{_LAST_READ_LOOP};
            $self->{_LAST_READ_LOOP} = undef;
            return $temp;
    }

    my $temp_handle = $self->{_FILE_HANDLE};
    while ( $segment = <$temp_handle> ) {
        chomp($segment);
        $self->{_LINE_COUNT}++;    
        $self->{_LAST_READ_SEGMENT} = $segment;
        @segment = split ( /\Q$self->{_ELEMENT_SEPERATOR}\E/, $segment );

        for my $level_handle (@{$self->{_ARRAY_OF_HANDLES}}) {
            foreach my $tree_index (@$level_handle) {
                my $loop = $self->{_CF}->{looptree}->[$tree_index][1];
                my @left = split ( /:/, $self->{_CF}->{segmentstart}->{$loop}->[0] );
                if ( $left[0] eq $segment[0] ) {
                    if ( $left[2] eq "" ) {
                        $current_loop = $self->{_CF}->{looptree}->[$tree_index][1];
                        $self->{_CURRENT_LEVEL} = $self->{_CF}->{looptree}->[$tree_index][0];
                        my $diff = $self->{_TRACK_LEVEL} - $self->{_CF}->{looptree}->[$tree_index][0];
                        $self->{_TRACK_LEVEL} = $self->{_CF}->{looptree}->[$tree_index][0];
                        while ( $diff > 0 ) {
                            shift ( @{$self->{_ARRAY_OF_HANDLES}} );
                            $diff--;
                        }
                        my @next_level = $self->{_CF}->get_next_level ( $tree_index );
                        if ( 'END' ne $next_level[0] ) {
                            $self->{_TRACK_LEVEL}++;
                            unshift ( @{$self->{_ARRAY_OF_HANDLES}}, \@next_level );
                            return $current_loop;
                        }
                        return $current_loop;
                    }
                    else {
                        my @qual = split ( /,/, $left[2] );
                        if (( grep { $_ eq $segment[$left[1]] } @qual )) {
                            $current_loop = $self->{_CF}->{looptree}->[$tree_index][1];
                            $self->{_CURRENT_LEVEL} = $self->{_CF}->{looptree}->[$tree_index][0];
                            my $diff = $self->{_TRACK_LEVEL} - $self->{_CF}->{looptree}->[$tree_index][0];
                            $self->{_TRACK_LEVEL} = $self->{_CF}->{looptree}->[$tree_index][0];
                            while ( $diff > 0 ) {
                                shift ( @{$self->{_ARRAY_OF_HANDLES}} );
                                $diff--;
                            }
                            my @next_level = $self->{_CF}->get_next_level ( $tree_index );
                            if ( 'END' ne $next_level[0] ) {
                                $self->{_TRACK_LEVEL}++;
                                unshift ( @{$self->{_ARRAY_OF_HANDLES}}, \@next_level );
                                return $current_loop;
                            }
                            return $current_loop;
                        }
                    }
                }
            }
        }
    }
    close ($self->{_FILE_HANDLE});
    return;
}


sub _parse_loop {
    my $self = shift;
    my ( $segment, @segment, @loop );

    if ( defined $self->{_LAST_READ_SEGMENT} ) {
            push (@loop, $self->{_LAST_READ_SEGMENT});
            $self->{_LAST_READ_SEGMENT} = undef;
    }

    my $temp_handle = $self->{_FILE_HANDLE};
    while ( $segment = <$temp_handle> ) {
        chomp($segment);
        $self->{_LINE_COUNT}++;    
        $self->{_LAST_READ_SEGMENT} = $segment;
        @segment = split ( /\Q$self->{_ELEMENT_SEPERATOR}\E/, $segment );

        for my $level_handle (@{$self->{_ARRAY_OF_HANDLES}}) {
            foreach my $tree_index (@$level_handle) {
                my $loop = $self->{_CF}->{looptree}->[$tree_index][1];
                my @left = split ( /:/, $self->{_CF}->{segmentstart}->{$loop}->[0] );
                if ( $left[0] eq $segment[0] ) {
                    if ( $left[2] eq "" ) {
                        $self->{_LAST_READ_LOOP} = $self->{_CF}->{looptree}->[$tree_index][1];
                        $self->{_CURRENT_LEVEL} = $self->{_CF}->{looptree}->[$tree_index][0];
                        my $diff = $self->{_TRACK_LEVEL} - $self->{_CF}->{looptree}->[$tree_index][0];
                        $self->{_TRACK_LEVEL} =  $self->{_CF}->{looptree}->[$tree_index][0];
                        while ( $diff > 0 ) {
                            shift ( @{$self->{_ARRAY_OF_HANDLES}} );
                            $diff--;
                        }
                        my @next_level = $self->{_CF}->get_next_level ( $tree_index );
                        if ( 'END' ne $next_level[0] ) {
                            $self->{_TRACK_LEVEL}++;
                            unshift ( @{$self->{_ARRAY_OF_HANDLES}}, \@next_level );
                            return @loop;
                        }
                        return @loop;
                    }
                    else {
                        my @qual = split ( /,/, $left[2] );
                        if (( grep { $_ eq $segment[$left[1]] } @qual )) {
                            $self->{_LAST_READ_LOOP} = $self->{_CF}->{looptree}->[$tree_index][1];
                            $self->{_CURRENT_LEVEL} = $self->{_CF}->{looptree}->[$tree_index][0];
                            my $diff = $self->{_TRACK_LEVEL} - $self->{_CF}->{looptree}->[$tree_index][0];
                            $self->{_TRACK_LEVEL} =  $self->{_CF}->{looptree}->[$tree_index][0];
                            while ( $diff > 0 ) {
                                shift ( @{$self->{_ARRAY_OF_HANDLES}} );
                                $diff--;
                            }
                            my @next_level = $self->{_CF}->get_next_level ( $tree_index );
                            if ( 'END' ne $next_level[0] ) {
                                $self->{_TRACK_LEVEL}++;
                                unshift ( @{$self->{_ARRAY_OF_HANDLES}}, \@next_level );
                                return @loop;
                            }
                            return @loop;;
                        }
                    }
                }
            }
        }
        push (@loop, $segment);
    }
    return @loop;
}



sub get_next_loop {
    my $self = shift;
    my $loop = undef;

    my $original_line_seperator = $/;
    $/ = $self->{_SEGMENT_SEPERATOR};

    $loop = $self->_parse_loop_start;

    $/ = $original_line_seperator;

    if ( ! defined $loop ) { return }
    if ( 'IEA' eq $loop ) {
        if ( ! eof($self->{_FILE_HANDLE}) ) {
            $self->_set_seperator;
        }
    }
    return $loop;
}


sub get_next_pos_loop {
    my $self = shift;
    my $loop = undef;

    my $original_line_seperator = $/;
    $/ = $self->{_SEGMENT_SEPERATOR};

    $loop = $self->_parse_loop_start;

    $/ = $original_line_seperator;

    if ( ! defined $loop ) { return }
    if ( 'IEA' eq $loop ) {
        if ( ! eof($self->{_FILE_HANDLE}) ) {
            $self->_set_seperator;
        }
    }
    return ($self->{_LINE_COUNT}, $loop);
}


sub get_next_pos_level_loop {
    my $self = shift;
    my $loop = undef;

    my $original_line_seperator = $/;
    $/ = $self->{_SEGMENT_SEPERATOR};

    $loop = $self->_parse_loop_start;

    $/ = $original_line_seperator;

    if ( ! defined $loop ) { return }
    if ( 'IEA' eq $loop ) {
        if ( ! eof($self->{_FILE_HANDLE}) ) {
            $self->_set_seperator;
        }
    }
    return ($self->{_LINE_COUNT}, $self->{_CURRENT_LEVEL}, $loop);
}


sub get_loop_segments {
    my $self = shift;
    my @loop = ();

    my $original_line_seperator = $/;
    $/ = $self->{_SEGMENT_SEPERATOR};

    @loop = $self->_parse_loop;

    $/ = $original_line_seperator;

    return @loop;
}


sub print_tree {
    my $self  = shift;
    my ($pad, $index, $segment);

    while ( my ($pos, $level, $loop) = $self->get_next_pos_level_loop ) {
        if ( $level != 0 ) {
            $pad = '  |' x $level; 
            print "       $pad--$loop\n";
            $pad = '  |' x ( $level + 1 ); 
            my @loop = $self->get_loop_segments;
            foreach $segment (@loop) {
                $index = sprintf ( "%+7s", $pos++ );
                print "$index$pad-- $segment\n";
            }
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
  $p->parse ( file => '837.txt',
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

$p->get_segment_seperator;
   Get the segment seperator.

$p->get_element_seperator;
   Get the element seperator.

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

Prasad Poruporuthan, I<prasad@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright 2003 by Prasad Poruporuthan

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
