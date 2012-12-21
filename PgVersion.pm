use FileHandle;
use strict;

####################################################################
# PgVersion.pm - Module of pgfsck. Handles version dependancies.   #
# Copyright Martijn van Oosterhout <kleptog@svana.org> April 2002  #
#                                                                  #
# This program understands the internal structure of the tables    #
# and attempts to check them. It picks up on many types of errors. #
# It is also a dumping program of last resort. It will read the    #
# table and can output insert statements to reconstruct the table  #
# (or a version of it anyway). It won't reconstruct your schema    #
# though.                                                          #
#                                                                  #
# This program may be distributed under the sames terms as         #
# PostgreSQL itself.                                               #
####################################################################

my $datapath;   # Stored datapath
my $version;    # Version of DB, times 10
my $dboid;      # OID of database
my $dbname;     # Name of database

# Test and path, extract version
sub SetDataPath ($)
{
  my $path = shift;

  $datapath = $path;

  my $file = new FileHandle "<$path/PG_VERSION" or die "Couldn't access database at $path ($!)\n";

  my $v = <$file>;
  chomp $v;

  $version = $v * 10;  #  6.5 => 65, 7.1 => 71

  return $version;
}

# Set name and oid of database
# Need both since don't know which will be needed
sub SetDatabase ($$)
{
  ($dbname,$dboid) = @_;

  return $dbname;
}

# Opens a relation in the database, given name and oid
# Need both since don't know which will be needed
sub OpenRelation ($$)
{
  my( $class, $classoid ) = @_;

  my $filename;

  my @choices;

  # It's either a global file or a per database one
  if( $version < 71 ) {   # Disk layout changed in 7.1 (iirc)
    @choices = ( "$datapath/$class", "$datapath/base/$dbname/$class" );
  } else {
    @choices = ( "$datapath/global/$classoid", "$datapath/base/$dboid/$classoid" );
  }

  foreach(@choices)
  {
    if( -e $_ )
    { $filename = $_; last }
  }

  die "Couldn't find relation $class($classoid)\n" unless defined $filename;

  my $file = new FileHandle "<$filename" or die "Couldn't open relation $class($classoid) ($!)\n";

  return $file;
}

# Get the approprite description for this version
sub GetPageHeader ()
{
  if( $version < 71 )   # 7.2 added a few fields for WAL
  {
    return new DiskStruct( "SSSS", [ qw(lower upper special opaque) ] );
  }
  elsif ( $version == 83 ) 
  {
    print "OM: 8.3 headers\n";
    return new DiskStruct( "LLLSSSCCI", [ qw(lsn1 lsn2 sui lower upper special version pagesize prunexid) ] );
  }
  else
  {
    return new DiskStruct( "LLLSSSCC", [ qw(lsn1 lsn2 sui lower upper special version pagesize) ] );
  }
}

# Get the approprite description for this version
# Extracted from http://developer.postgresql.org/cvsweb.cgi/pgsql/src/include/catalog/pg_attribute.h
sub GetPGAttribute ()
{
  if( $version < 70 )   # 7.0 added a new field
  {
    return new DiskStruct( "LA32Lf ss lll CCA CC", [ qw(attrelid attname atttypid attdisbursion  attlen attnum  
                           attnelems attcacheoff atttypmod  attbyval attisset attalign  
                           attnotnull atthasdef) ] );
  }
  elsif( $version < 73 )  # 7.3 increase length of name type
  {
    return new DiskStruct( "LA32Ll ss lll CACA CC", [ qw(attrelid attname atttypid attstattarget  attlen attnum  
                           attndim attcacheoff atttypmod  attbyval attstorage attisset attalign  
                           attnotnull atthasdef) ] );
  }
  elsif( $version < 80 )
  {
    return new DiskStruct( "LA64Ll ss lll CACA CC", [ qw(attrelid attname atttypid attstattarget  attlen attnum  
                           attndim attcacheoff atttypmod  attbyval attstorage attisset attalign  
                           attnotnull atthasdef) ] );
  }
  elsif( $version == 83)
  { 
    print "OM: Attribute structure 83\n";
    return new DiskStruct( "LA64Ll ss lll CCC cccc L", [ qw(attrelid attname atttypid attstattarget  attlen attnum  
                           attndim attcacheoff atttypmod  attbyval attstorage attalign attnotnull atthasdef attisdropped attislocal attinhcount 
                           ) ] );
  }
  else
  {
    return new DiskStruct( "LA64Ll ss lll CCC", [ qw(attrelid attname atttypid attstattarget  attlen attnum  
                           attndim attcacheoff atttypmod  attbyval attstorage attalign  
                           ) ] );
  }
}

sub GetTupleHeader ()
{
  if( $version < 73 )   # 7.3 completely changed the header
  {
    return new DiskStruct( "LLLLLSSSSSC", [ qw( oid cmin cmax xmin xmax tid1 tid2 tid3 natts infomask size ) ] );
  }
  elsif( $version < 80 )  # Grew by 4 bytes in 8.0
  {
    return new DiskStruct( "LLLSSSSSC", [ qw( xmin xmax xvac tid1 tid2 tid3 natts infomask size ) ] );
  }
  elsif ( $version == 83 )
  {
    print "OM: tuple 83\n";
    return new DiskStruct( "LLLSSSSSC", [ qw( xmin xmax xvac tid1 tid2 tid3 natts infomask size ) ] );
  }
  else
  {
    return new DiskStruct( "LLLLSSSSSC", [ qw( xmin cmin xmax cmax tid1 tid2 tid3 natts infomask size ) ] );
  }
}
1;
