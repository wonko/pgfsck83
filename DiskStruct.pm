package DiskStruct;
use strict;

# Copyright Martijn van Oosterhout <kleptog@svana.org> - April 2002
# You may do whatever you like with code code.

# Package whose sole purpose is to encapsulate the unpacking of structures
# in strings into hashes. In pgfsck it's used for decoding the page header
# and the tuples header. It's not quite flexible enough to deal with the
# contents of tuples.

sub new
{
  my ($class,$structure,$fields) = @_;

  return bless { _structure => $structure, _fields => $fields }, $class;
}

sub decode  ($)
{
  my ($self,$str) = @_;

  my %h;

  my @F = unpack( $self->{_structure}."a*", $str );

  if( @F != @{ $self->{_fields} }+1 )
  {
    $h{_error} = "Wrong number of fields in structure ($self->{_structure}) (".scalar(@F)."!=".scalar(@{ $self->{_fields} }).")\n";
  }

  @h{@{ $self->{_fields} }} = @F;

  $h{_sizeof} = length($str) - length($F[-1]);

  return \%h;
}

1;
