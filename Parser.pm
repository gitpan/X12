# Copyright 2003 by Prasad Poruporuthan
# All rights reserved.
# 
# This library is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.

package X12::Parser;

#use 5.008;
use strict;
#use warnings;

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

our $VERSION = '0.02';

# Preloaded methods go here.
use X12::Parser::Cf;
my $s = undef;
my $c_L = undef;

sub new {
    my $self = {};
    $self->{file} = undef;
    $self->{conf} = undef;
    $self->{cf} = undef;
    $self->{array} = undef;
    $self->{analysis} = undef;
    $self->{where} = -1;
    $self->{size} = -1;
    return bless $self;
}


sub parse {
    my $self = shift;
    my %params = @_;
    my $ANALYSIS = undef;
    my $size = undef;
    $self->{file} = $params{file};
    $self->{conf} = $params{conf};
    $self->{analysis} = \$ANALYSIS;
    $self->{size} = \$size;
    $self->_load;
    for ( my $i=0; $i<$self->{size}; $i++ ) {
        vec ( $self->{analysis}, $i, 16 ) = 0xFFFF;
    }
    $c_L = 1;
    my @level_one = $self->_get_level_one;
    $self->_parse ( 0, \@level_one );
}


sub _load {
    my $self = shift;
    my $cf = new X12::Parser::Cf;
    $self->{cf}  = $cf;
    $cf->load ("$self->{conf}") if defined $self->{conf};

    open (FILE, "$self->{file}") || die "error: cannot open file $self->{file}\n";
    my $isa = undef;
    if ( read(FILE, $isa, 106) != 106 ) {
        close (FILE);
        die "error: invalid file format $self->{file}\n";
    }

    my $line_seperator = $/;

    $/ = substr ($isa, 105, 1);
    $s = substr ($isa, 3, 1);

    my @array;
    seek (FILE, 0, 0);
    my @array = <FILE>;
    close (FILE);
    chop(@array);
    $self->{array} = \@array;
    $self->{size} = @array;

    $/ = $line_seperator;
}


sub _parse {
    my $self = shift;
    my $array_pos = shift;
    my @array_of_handles = @_;
    my ($segment, @segment );

    RECURSION:
    for (my $i=$array_pos; $i<$self->{size}; $i++) {
        $segment = $self->{array}->[$i];
        @segment = split ( /\Q$s\E/, $segment );

        for my $level_handle (@array_of_handles) {
            foreach my $pos (@$level_handle) {
                my $loop = $self->{cf}->{looptree}->[$pos][1];
                my @left = split ( /:/, $self->{cf}->{segmentstart}->{$loop}->[0] );
                if ( $left[0] eq $segment[0] ) {
                    if ( $left[2] eq "" ) {
                        vec ( $self->{analysis}, $i, 16 ) = $pos;
                        my $diff = $c_L - $self->{cf}->{looptree}->[$pos][0];
                        $c_L =  $self->{cf}->{looptree}->[$pos][0];
                        while ( $diff > 0 ) {
                            shift ( @array_of_handles );
                            $diff--;
                        }
                        my @next_level = $self->_get_next_level ( $pos );
                        if ( 'END' ne $next_level[0] ) {
                            $c_L++;
                            my $ref = \@next_level;
                            unshift ( @array_of_handles, $ref );
                            $array_pos = $i + 1;
                            next RECURSION; # recursion
                        }
                        next RECURSION; # already matched goto next line
                    }
                    else {
                        my @qual = split ( /,/, $left[2] );
                        if (( grep { $_ eq $segment[$left[1]] } @qual )) {
                            vec ( $self->{analysis}, $i, 16 ) = $pos;
                            my $diff = $c_L - $self->{cf}->{looptree}->[$pos][0];
                            $c_L =  $self->{cf}->{looptree}->[$pos][0];
                            while ( $diff > 0 ) {
                                shift ( @array_of_handles );
                                $diff--;
                            }
                            my @next_level = $self->_get_next_level ( $pos );
                            if ( 'END' ne $next_level[0] ) {
                                $c_L++;
                                my $ref = \@next_level;
                                unshift ( @array_of_handles, $ref );
                                $array_pos = $i + 1;
                                next RECURSION; # recursion
                            }
                            next RECURSION; # already matched goto next line
                        }
                    }
                }
            }
        }
    }
    return;
}


sub _get_level_one {
    my $self = shift;
    my @temp = (); 
    for ( my $i=0; $i < @{$self->{cf}->{looptree}}; $i++ ) {
        if ( $self->{cf}->{looptree}->[$i][0] == 1 ) {
            push ( @temp, $i );
        }
    }
    return @temp;
}


sub _get_next_level {
    my $self = shift;
    my $current_pos  = shift;
    my $current_level = $self->{cf}->{looptree}->[$current_pos][0];
    my $next_level = $self->{cf}->{looptree}->[$current_pos + 1][0];
    my @temp = (); 

    if ( $current_level < $next_level ) {
        $current_pos++;
        while ( $self->{cf}->{looptree}->[$current_pos][0] > $current_level ) {
            if ( $self->{cf}->{looptree}->[$current_pos][0] == $next_level ) {
                push ( @temp, $current_pos );
            }
            $current_pos++;
        }
    }
    else {
        push ( @temp , 'END' );
    }
    return @temp;
}


sub get_next_loop {
    my $self = shift;
    my $i    = $self->{where};

    for ( $i++ ;$i<$self->{size}; $i++ ) {
        if ( vec ( $self->{analysis}, $i, 16 ) != 0xFFFF ) {
            $self->{where} = $i;
            return ( $self->{cf}->{looptree}->[vec($self->{analysis},$i,16)]->[1] );
        }
    }
    if ( $i >= $self->{size} ) {
        return 0;
    }
}


sub get_loop_segments {
    my $self = shift;
    my $loop = shift;
    my @temp = ();
    my $i    = $self->{where};

    if ( $self->{cf}->{looptree}->[vec ( $self->{analysis}, $i, 16 )]->[1] ne $loop ) {
        return @temp;
    }
    do {
        push ( @temp, $self->{array}->[$i] );
    } while ( vec ( $self->{analysis}, ++$i, 16 ) == 0xFFFF && $i < $self->{size} );
    return @temp;
}


sub get_next_pos_loop {
    my $self = shift;
    my $i    = $self->{where};

    for ( $i++ ;$i < $self->{size}; $i++ ) {
        if ( vec ( $self->{analysis}, $i, 16 ) != 0xFFFF ) {
            $self->{where} = $i;
            return ( $i, $self->{cf}->{looptree}->[vec($self->{analysis},$i,16)]->[1] );
        }
    }
    if ( $i >= $self->{size} ) {
        return;
    }
}


sub get_next_pos_level_loop {
    my $self = shift;
    my $i    = $self->{where};

    for ( $i++ ;$i < $self->{size}; $i++ ) {
        if ( vec ( $self->{analysis}, $i, 16 ) != 0xFFFF ) {
            $self->{where} = $i;
            return ( $i, $self->{cf}->{looptree}->[vec($self->{analysis},$i,16)]->[0],
                         $self->{cf}->{looptree}->[vec($self->{analysis},$i,16)]->[1] );
        }
    }
    if ( $i >= $self->{size} ) {
        return;
    }
}


sub get_segments {
    my $self = shift;
    my $i    = shift;
    my @temp = ();

    if ( $i < 0 || $i >= $self->{size} ) {
        return @temp;
    }
    do {
        push ( @temp, $self->{array}->[$i] );
    } while ( vec ( $self->{analysis}, ++$i, 16 ) == 0xFFFF && $i < $self->{size} );
    return @temp;
}


sub reset_pos {
    my $self = shift;
    $self->{where} = -1;
}


sub print_tree {
    my $self  = shift;
    my $index = undef;
    my $pad   = undef;
    my $level = undef;

    for (my $i=0; $i<$self->{size}; ) {
        $level = $self->{cf}->{looptree}->[vec($self->{analysis},$i,16)]->[0];
        if ( $level != 0 ) {
            $pad = '  |' x $level; 
            print "       $pad--$self->{cf}->{looptree}->[vec($self->{analysis},$i,16)]->[1]\n";
            $pad = '  |' x ( $level + 1 ); 
            do {
                $index = sprintf ( "%+7s", $i+1 );
                print "$index$pad-- $self->{array}->[$i]\n";
            } while ( vec ( $self->{analysis}, ++$i, 16 ) == 0xFFFF && $i < $self->{size} );
        }
        else {
            $i++;
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
   my @loop = $p->get_loop_segments ($loop); 
 }

# or use this method instead 
 while ( my ($pos, $loop) = $p->get_next_pos_loop ) { 
   my @loop = $p->get_segments ($pos); 
 }

# or use
 while ( my ($pos, $level, $loop) = $p->get_next_pos_level_loop ) {
   my @loop = $p->get_segments ($pos);
 }


=head1 ABSTRACT

X12::Parser package provides a efficient way to parse X12
transaction files. Although this packages is built keeping HIPAA
related X12 transactions in mind, it is flexible and can be
adapted to any X12 or similar transactions.

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

$p->parse ( file => '837.txt', conf => 'X12-837P.cf' );
   This method takes two arguments. The first argument is the 
   transaction file which needs to be parsed. The second argument 
   specifies the configuration file to be used for parsing the 
   transaction file. 

   This package is a generic parser for parsing files which use a
   format similar to the X12 specification. The ability to parse
   different transaction types is provided by means of using different
   configuration files. The configuration files for all the X12 HIPAA
   transactions are provided with this package.

   To create your own configuration file read the X12::Parser::Readme 
   man page.

$p->get_next_loop ();
   This function returns the next loop name for the transaction file
   which is being parsed. The loop name is as specified in the cf
   file.

$p->get_loop_segments ($loop);
   Pass the loop name returned by get_next_loop() to obtain the 
   segments in this loop. This function is to be used in tandem with 
   the get_next_loop. If not it may return/produce undesired results. 
   get_next_loop() and get_loop_segments() internally keep record of 
   the current loop position, so get_loop_segments will return the 
   current loop segments even if you do not pass the loop name.

$p->get_next_pos_loop ();
   This function returns the next loop name and the loop position.
   Note 0 corresponds to the first segment. 

$p->get_next_pos_level_loop ();
   Same as get_next_pos_loop() except that in addition this function
   returns the level of the loop. The level corresponds to the level
   of the loop in the loop hierarchy. The top level loop has level 1.

$p->get_segments ($pos);
   get_segments returns an array of segments in the loop starting at
   position $pos. If the specified position does not correspond to a 
   loop, the function returns the segment at position $pos. 

$p->reset_pos ();
   Resets the pointer used by get_next_* functions. This causes the
   get_next_* functions to start parsing again from the begining of
   the file.

$p->print_tree;
   prints the transaction file in a tree format.

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
these files. The user may use them as is at his own risk.

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

Prasad Poruporuthan, E<lt>pprasadb@planet-save.com<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2003 by Prasad Poruporuthan

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
