package FCGI::Client::RecordFactory;
use strict;
use warnings;
use FCGI::Client::Constant;

# generate generic record
sub generate {
    my ($class, $type, $request_id, $content) = @_;
    #  0 unsigned char version;
    #  1 unsigned char type;
    #  2 unsigned char requestIdB1; <= (B1<<8)+B0, network byte order
    #  3 unsigned char requestIdB0;
    #  4 unsigned char contentLengthB1;
    #  5 unsigned char contentLengthB0;
    #  6 unsigned char paddingLength;
    #  7 unsigned char reserved;
    #    unsigned char contentData[contentLength];
    #    unsigned char paddingData[paddingLength];
    #
    # n => An unsigned short (16−bit) in "network" (big−endian) order.
    # C => An unsigned char (octet) value.
    my $buf = pack('CCnnCC',
        FCGI_VERSION_1,
        $type,
        $request_id,
        length($content),
        0,
        0,
    );
    $buf .= $content;
    return $buf;
}

# generate FCGI_BEGIN_REQUEST record
sub begin_request {
    my ($class, $request_id, $role, $flags) = @_;
    # typedef struct {
    #     unsigned char roleB1;
    #     unsigned char roleB0;
    #     unsigned char flags;
    #     unsigned char reserved[5];
    # } FCGI_BeginRequestBody;
    my $content = pack(
        'nCCCCCC',
        $role,
        $flags,
        0,0,0,0,0
    );
    $class->generate(FCGI_BEGIN_REQUEST, $request_id, $content);
}

# generate FCGI_PARAMS record
sub params {
    my ($class, $request_id, %params)  = @_;
    my $content = '';
    while (my ($k, $v) = each %params) {
        my $klen = length($k);
        my $vlen = length($v);
        $content .= ($klen < 127) ? pack('C', $klen) : pack('N', $klen);
        $content .= ($vlen < 127) ? pack('C', $vlen) : pack('N', $vlen);
        $content .= $k;
        $content .= $v;
    }
    $class->generate(FCGI_PARAMS, $request_id, $content);
}

# generate FCGI_STDIN record
sub stdin {
    my ($class, $request_id, $content)  = @_;
    $content ||= '';
    $class->generate(FCGI_STDIN, $request_id, $content);
}

1;
