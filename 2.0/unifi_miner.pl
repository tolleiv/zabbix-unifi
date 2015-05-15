#!/usr/bin/perl
#
#  (C) sadman@sfi.komi.com 2015
#  tanx to Jakob Borg (https://github.com/calmh/unifi-api) for some and methods ideas 
#
#
use strict;
use warnings;
use Switch;
use JSON;
use Data::Dumper;
use HTTP::Cookies;
use IO::Socket::SSL;
use LWP;
#use LWP::Simple;
use Getopt::Std;
# SSL_verify_mode => 0 eq SSL_verify_mode => IO::Socket::SSL::SSL_VERIFY_NONE

use constant {
     ACT_COUNT => 'count',
     ACT_SUM => 'sum',
     CONTROLLER_VERSION_2 => 'v2',
     CONTROLLER_VERSION_3 => 'v3',
     CONTROLLER_VERSION_4 => 'v4',
     DEBUG_LOW => 1,
     DEBUG_MID => 2,
     DEBUG_HIGH => 3,
     KEY_ITEMS_NUM => 'items_num',
     MINER_VERSION => '0.999',
     MSG_UNKNOWN_CONTROLLER_VERSION => "Version of controller is unknown: ",
     OBJ_AP => 'ap',
     OBJ_WLAN => 'wlan',
     TRUE => 1,
     FALSE => 0,
};


sub getJSON;
sub unifiLogin;
sub unifiLogout;
sub fetchData;
sub lldJSONGenerate;
sub getMetric;
sub getObject;

my %options=();
getopts("a:d:i:k:l:n:o:p:s:u:v:", \%options);

#########################################################################################################################################
#
#  default values for global scope
#
########################################################################################################################################
my $globalConfig={location => "https://127.0.0.1:8443", version => "v4", sitename => "default", object => OBJ_WLAN, action => ACT_COUNT,
                  username => "stat", password => "stat", debug => "0" };

$globalConfig->{action}     = $options{a} if defined $options{a};
$globalConfig->{debug}      = $options{d} if defined $options{d};
$globalConfig->{id}         = $options{i} if defined $options{i};
$globalConfig->{key}        = $options{k} if defined $options{k};
$globalConfig->{location}   = $options{l} if defined $options{l};
$globalConfig->{null_char}  = $options{n} if defined $options{n};
$globalConfig->{object}     = $options{o} if defined $options{o};
$globalConfig->{password}   = $options{p} if defined $options{p};
$globalConfig->{sitename}   = $options{s} if defined $options{s};
$globalConfig->{username}   = $options{u} if defined $options{u};
$globalConfig->{version}    = $options{v} if defined $options{v};

switch($globalConfig->{version}){
   case CONTROLLER_VERSION_4
     {
       $globalConfig->{api_path}="$globalConfig->{location}/api/s/$globalConfig->{sitename}";
       $globalConfig->{login_path}="$globalConfig->{location}/api/login";
       $globalConfig->{logout_path}="$globalConfig->{location}/logout";
       $globalConfig->{login_data}="{\"username\":\"$globalConfig->{username}\",\"password\":\"$globalConfig->{password}\"}";
       $globalConfig->{login_type}='json';
     }
   case CONTROLLER_VERSION_3
     {
       $globalConfig->{api_path}="$globalConfig->{location}/api/s/$globalConfig->{sitename}";
       $globalConfig->{login_path}="$globalConfig->{location}/login";
       $globalConfig->{logout_path}="$globalConfig->{location}/logout";
       $globalConfig->{login_data}="username=$globalConfig->{username}&password=$globalConfig->{password}&login=login";
       $globalConfig->{login_type}='x-www-form-urlencoded';
     }
   case CONTROLLER_VERSION_2
     {
       $globalConfig->{api_path}="$globalConfig->{location}/api";
       $globalConfig->{login_path}="$globalConfig->{location}/login";
       $globalConfig->{logout_path}="$globalConfig->{location}/logout";
       $globalConfig->{login_data}="username=$globalConfig->{username}&password=$globalConfig->{password}&login=login";
       $globalConfig->{login_type}='x-www-form-urlencoded';
     }
   else      
     {
        die MSG_UNKNOWN_CONTROLLER_VERSION, $globalConfig->{version};
     }
 }


print "\n[#]   Global config data:\n\t", Dumper $globalConfig if $globalConfig->{debug} >= DEBUG_HIGH;

my $res="";

my $ua = LWP::UserAgent-> new();
$ua->ssl_opts( SSL_verify_mode => IO::Socket::SSL::SSL_VERIFY_NONE, SSL_hostname => '', verify_hostname => 0 );
$ua->cookie_jar(HTTP::Cookies->new(autosave => 1));
$ua->agent( "UniFi Miner/" . MINER_VERSION . " (perl engine)");

print "\n[*] Login into UniFi controller" if $globalConfig->{debug} >= DEBUG_LOW;
unifiLogin();

print "\n[*] Get data" if $globalConfig->{debug} >= DEBUG_LOW;

if ($globalConfig->{object}) {
   if ($globalConfig->{key}){
       # get metric. if $globalConfig->id is setted then metric of this object has returned. if not - $globalConfig->action is run for all items in object
       $res=getMetric(getObject(), $globalConfig->{key}, 1);
     }
   else
     { 
        # metric is null - generate lld
        $res=lldJSONGenerate(getObject());
     }
}
# what to do with undef value if key not exist in json?
if (defined($globalConfig->{null_char}))
 { 
   $res = $res ? $res : $globalConfig->{null_char};
 }
print "\n" if  $globalConfig->{debug} >= DEBUG_LOW;
print  "$res\n";

print "\n[*] Logout from UniFi controller" if  $globalConfig->{debug} >= DEBUG_LOW;
unifiLogout();

sub getMetric{
    # $_[0] - array/hash with info
    # $_[1] - key
    # $_[2] - dive level
    print "\n[>] ($_[2]) getMetric started" if $globalConfig->{debug} >= DEBUG_LOW;
    my $result;
    my $paramValue;
    my $table=$_[0];
    my $tableName;
    my $key=$_[1];
    my $subKeyDetected=FALSE;
    print "\n[#]   options: key='$_[1]' action='$globalConfig->{action}'" if $globalConfig->{debug} >= DEBUG_MID;
    print "\n[+]   incoming object info:'\n\t", Dumper $_[0] if $globalConfig->{debug} >= DEBUG_HIGH;

    # maybe this code to regexp spliting need rewriten
    # if comma found - then key will be split to tablename.key
    my $commaPos=index($_[1], ".");
    if ($commaPos > 0) {
        $tableName= substr($_[1], 0, $commaPos);
        $key= substr($_[1], $commaPos+1);
        $subKeyDetected = TRUE;
    }
    # Cheking for type of $_[0].
    # Array must be explored for key value in each element
    if (ref($_[0]) eq "ARRAY") 
       {
         $result=@{$table};
         print "\n[.] $result sections given." if $globalConfig->{debug} >= DEBUG_MID;
         # if metric ask "how much items (AP's for example) in all" - just return array size (previously calculated in $result) and do nothing more
         if ($key ne KEY_ITEMS_NUM) 
           {
             print "\n[.] taking value from all sections" if $globalConfig->{debug} >= DEBUG_MID;
             $result=0;
             foreach my $hashRef (@{$table}) {
                  # If need to analyze elements in subtable...
                  if ($subKeyDetected) { 
                     # Do recursively calling getMetric func with subtable and subkey and get value from it
                     $paramValue=getMetric($hashRef->{$tableName}, $key, $_[2]+1); 
                   }
                  else {
                     # if it just "first-level" key - get it value
                     die "Key $key not exist" unless defined( $hashRef->{$key});
                     $paramValue=$hashRef->{$key};
                   }
                  # need to fix trying sum of not numeric values
                  # do some math with value - sum or count               
                  if ($globalConfig->{action} eq ACT_SUM)
                     { $result+=$paramValue if ($paramValue);}
                  else
                     { $result++ if ($paramValue); }
              }#foreach;
           }
       }
    else 
       {
         # it is not array. Just get metric value by hash index
         print "\n[.] Just one section given. Get metric." if $globalConfig->{debug} >= DEBUG_MID;
         # if subkey was detected - do recursively calling getMetric func with subtable and subkey and get value from it
         # Otherwise - just return value for given key
         if ($subKeyDetected) 
            { $result=getMetric($table->{$tableName}, $key, $_[2]+1); }
         else { 
              die "Key $key not exist" unless defined( $table->{$key});
              $result=$table->{$key};
            }
       }
  print "\n[>] getMetric finished ($result)" if $globalConfig->{debug} >= DEBUG_LOW;
  return $result;
}

sub getObject
{
   print "\n[+] getObject started" if $globalConfig->{debug} >= DEBUG_LOW;
   print "\n[+]   options object=$globalConfig->{object}" if $globalConfig->{debug} >= DEBUG_MID;
   my $result;
   my $objPath="";
   switch ($globalConfig->{object}) {
     case OBJ_WLAN { $objPath='list/wlanconf'; }
     case OBJ_AP   { $objPath='stat/device'; }
     else { die "[!] Unknown object given"; }
   }
   $result=fetchData($objPath);
   print "\n[-] getObject finished" if $globalConfig->{debug} >= DEBUG_LOW;
   return $result;
}

sub fetchData {
   # $_[0] - fetch path
   print "\n[+] fetchData started" if $globalConfig->{debug} >= DEBUG_LOW;
   print "\n[#]   options: id='$globalConfig->{id}'" if $globalConfig->{debug} >= DEBUG_MID && $globalConfig->{id};
   print "\n[#]   options: path='$globalConfig->{api_path}/$_[0]'" if $globalConfig->{debug} >= DEBUG_MID;
   my $result=getJSON("$globalConfig->{api_path}/$_[0]");
   print "\n[<]   recieved from JSON requestor:\n\t", Dumper $result if $globalConfig->{debug} >= DEBUG_HIGH;
   # if ID stored in global config, then seeking for object with equal ID in JSON data
   if ($globalConfig->{id}) {
       foreach my $hashRef (@{$result}) { if ($hashRef->{'_id'} eq $globalConfig->{'id'}) { $result=$hashRef; last; } } #foreach;
     }
   print "\n[<]   fetched data:\n\t", Dumper $result if $globalConfig->{debug} >= DEBUG_HIGH;
   print "\n[-] fetchData finished" if $globalConfig->{debug} >= DEBUG_LOW;
   return $result;
}

sub lldJSONGenerate{
    print "\n[+] lldJSONGenerate started" if $globalConfig->{debug} >= DEBUG_LOW;
    print "\n[#]   options: object='$globalConfig->{object}'" if $globalConfig->{debug} >= DEBUG_MID;
    my $lldData;
    my $resut;
    my $lldItem = 0;
    foreach my $hashRef (@{$_[0]}) {
       switch ($globalConfig->{object}) {
         case OBJ_WLAN {
              $lldData->{'data'}->[$lldItem]->{'{#ALIAS}'}=$hashRef->{'name'};
              $lldData->{'data'}->[$lldItem]->{'{#ID}'}=$hashRef->{'_id'};
         }
         case OBJ_AP {
              $lldData->{'data'}->[$lldItem]->{'{#ALIAS}'}=$hashRef->{'name'};
              $lldData->{'data'}->[$lldItem]->{'{#IP}'}=$hashRef->{'ip'};
              $lldData->{'data'}->[$lldItem]->{'{#ID}'}=$hashRef->{'_id'};
              $lldData->{'data'}->[$lldItem]->{'{#MAC}'}=$hashRef->{'mac'};
         }
       } #switch
       $lldItem++;
    } #foreach;
    $resut=to_json($lldData, {utf8 => 1, pretty => 1, allow_nonref => 1});
    print "\n[<]   generated lld:\n\t", Dumper $resut if $globalConfig->{debug} >= DEBUG_HIGH;
    print "\n[-] lldJSONGenerate finished" if $globalConfig->{debug} >= DEBUG_LOW;
    return $resut;
}

sub unifiLogin {
   # authenticate against unifi controller
   print "\n[>] unifiLogin started" if $globalConfig->{debug} >= DEBUG_LOW;
   print "\n[#]  options path='$globalConfig->{login_path}' type='$globalConfig->{login_type}' data='$globalConfig->{login_data}'" if $globalConfig->{debug} >= DEBUG_MID;
   my $response=$ua->post($globalConfig->{login_path}, 'Content_type' => "application/$globalConfig->{login_type}", 'Content' => $globalConfig->{login_data});
   print "\n[<]  HTTP respose:\n\t", Dumper $response if $globalConfig->{debug} >= DEBUG_HIGH;
   # v3 return 'OK' (code 200) on wrong auth
   die "\n[!] Login error:", $response->code if ($response->is_success && $globalConfig->{version} eq CONTROLLER_VERSION_3);
   # v3 return 'Redirect' (code 302) on success login
   die "\n[!] Other HTTP error:", $response->code if ($response->code ne '302' && $globalConfig->{version} eq CONTROLLER_VERSION_3);

   # v3 return 'Bad request' (code 400) on wrong auth
   die "\n[!] Login error:" if ($response->code eq '400' && $globalConfig->{version} eq CONTROLLER_VERSION_4);
   # v3 return 'OK' (code 200) on success login
   die "\n[!] Other HTTP error:", $response->code if ($response->is_error && $globalConfig->{version} eq CONTROLLER_VERSION_4);
   print "\n[-] unifiLogin finished sucesfull " if $globalConfig->{debug} >= DEBUG_LOW;
   return  $response->code;
}

sub unifiLogout {
   # $_[0] - bye message (?)
   print "\n[+] unifiLogout started" if $globalConfig->{debug} >= DEBUG_LOW;
   my $response=$ua->get($globalConfig->{logout_path});
   print "\n[-] unifiLogout finished" if $globalConfig->{debug} >= DEBUG_LOW;
}

sub getJSON {
   # $_[0] - uri string
   print "\n[+] getJSON started" if $globalConfig->{debug} >= DEBUG_LOW;
   print "\n[#]   options url=$_[0]" if $globalConfig->{debug} >= DEBUG_MID;
   my $req = HTTP::Request->new( 'GET', $_[0]);
   my $response=$ua->request( $req );
   my $objJSON=JSON->new->utf8;
   # if request is not success - die
   die "[!] JSON taking error, HTTP code:", $response->status_line unless $response->is_success;
   print "\n[<]   fetched data:\n\t", Dumper $response->decoded_content if $globalConfig->{debug} >= DEBUG_HIGH;
   my $result=$objJSON->decode($response->decoded_content);
   my $jsonData=$result->{data}; 
   my $jsonMeta=$result->{meta};
   # server answer is ok ?
   if ($jsonMeta->{'rc'} eq 'ok') 
      { 
        print "\n[-] getJSON finished sucesfull" if $globalConfig->{debug} >= DEBUG_LOW;
        return $jsonData=$jsonData;    
      }
   else
      { die "[!] postJSON error: rc=$jsonMeta->{'rc'}"; }
}
