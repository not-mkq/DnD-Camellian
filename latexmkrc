use Cwd qw(getcwd);
use File::Path qw(make_path);

my $font_cache = getcwd() . "/tex-cache";
make_path($font_cache);
$ENV{'TEXMFCACHE'} = $font_cache;