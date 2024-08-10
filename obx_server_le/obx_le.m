//
//  obx_le.m
//  obx_server_le
//

#import <Foundation/Foundation.h>
#include "obx_le.h"
#include "hdr_fabrik.h"
#include "directory.h"
#include <sys/stat.h>

extern NSWindowController <Feedback> * mammy;
void report(char* fmt, ...);

uint8_t obx_outbuff[2048];       // used by hdr_fabrik
uint16_t obx_datalen;
extern uint16_t max_pkt_len;
extern uint16_t remote_max_pkt_len;
extern uint16_t max_payload;

bool obx_connected = false;     // TODO ensure connect before get/put/setpath

extern uint16_t max_pkt_len;
uint32_t infile_length, get_bytes_received = 0;

uint8_t inget_name[128];     // could be filename or dir name
FILE* inget_file = NULL;
DIR* inget_dir = NULL;
uint32_t inget_len;         // file_len or dir_list_len
uint32_t inget_bytes_left = 0;
char list_dir[1024];
int list_dir_len;
struct dirent* dir_entry = NULL;
char download_path[1024];

uint32_t file_length(FILE* f)
{
    long ll;
    fseek(f, 0, SEEK_END);
    ll = ftell(f);
    //printf("ll = %ld\n", ll);
    fseek(f, 0, SEEK_SET);
    return (ll & 0xffffffffL);
}

bool prune_path(void)
{
    int k = strlen(download_path) - 2;
    
    while (k>0 && download_path[k] != '/') k--;
    if (k<0) { download_path[0] = '/'; download_path[1] = 0;  return false; }
    download_path[k+1] = 0;
    report("pruned path = %s\n", download_path);
    return true;
}

void incoming_connect(uint8_t *dataptr, int16_t datalen, NSOutputStream* outstream)
{
    uint8_t* inptr;
    [ mammy update: "incoming_connect\n" ];
    if (datalen < 7) {
        [ mammy update: "bad connect request\n" ];
        obx_outbuff[0] = kOBEXResponseCodeBadRequestWithFinalBit;
        obx_outbuff[1] = 0;  obx_outbuff[2] = 3;    // total length
        obx_datalen = 3;
    }
    else {
        inptr = dataptr + 5;
        remote_max_pkt_len = ntohs(*((uint16_t*) inptr));
        report("remote max pkt len=%d\n", remote_max_pkt_len);
        if (remote_max_pkt_len < HOST_MAX_PKT_LEN)  max_pkt_len = remote_max_pkt_len;
        else  max_pkt_len = HOST_MAX_PKT_LEN;
        init_obex_cmd(kOBEXResponseCodeSuccessWithFinalBit);
        add_version_flags_maxpkt();
        complete_obex();
        obx_connected = true;
    }
    [ outstream write: obx_outbuff maxLength: obx_datalen ];
}

void compile_get_response(uint8_t *buff, uint16_t bytes_read, bool endof)
{
    init_obex_cmd(kOBEXResponseCodeSuccessWithFinalBit);
    add_name_hdr(inget_name);
    add_length_hdr(inget_len);
    if (bytes_read)  add_body_hdr(buff, bytes_read, endof);
    complete_obex();
}

void incoming_get(uint8_t *dataptr, int16_t datalen, NSOutputStream* outstream)
{
    uint8_t* filename;
    char file_path[1024];
    uint8_t fbuff[2048]; // bigger than 1024 because listline can overflow
    uint16_t bytes_read;
    bool endof;
                // send as much as comfortably fits in packet leaving at least 1/8th for non-bod hdrs
    if (inget_file) {   // file open so send next chunk
        bytes_read = fread(fbuff, 1, max_payload, inget_file);
        inget_bytes_left -= bytes_read;
        endof = (inget_bytes_left <= 0);
        compile_get_response(fbuff, bytes_read, endof);
        if (endof) { fclose(inget_file);  inget_file = NULL;  [ mammy update: "transfer complete.\n"]; }
    }
    else {
        if (inget_dir) {    // dir open so send next list-batch
             bytes_read = batch_list(fbuff, max_pkt_len>>1, inget_dir, &endof);
             inget_bytes_left -= bytes_read;
             compile_get_response(fbuff, bytes_read, endof);
             if (endof)  { closedir(inget_dir); inget_dir = NULL; }
        }
        else {
            parse_input(dataptr, datalen);
            if (extract_name(&filename)) {
                report("incoming get %s\n", filename);
                // NSString* bund_path;
                // bund_path = [[NSBundle mainBundle] bundlePath ];
                // [bund_path getCString: file_path maxLength: 512 encoding: NSASCIIStringEncoding ];
                              
                // NSLog(@"%@", bund_path);
                // base path of file/dir to retreive from
                // nothing to find in bundle directory unless you copy files into it
                // so maybe set file_path to something like /Users/<username>/Downloads/
                // if you want access to pictures or music change
                // capabilities and/or entitlements and maybe mac settings
                strcpy(file_path, download_path);
                report("working directory=%s\n", file_path );
                
                // drop leading / if present
                if (*filename == '/') strncat(file_path, filename+1, 127);
                else  strncat(file_path, filename, 128);
                report("path=%s\n", file_path);
    
                if (is_directory(file_path)) {
                    [ mammy update: "is directory\n" ];
                    strcpy(list_dir, file_path);
                    list_dir_len = strlen(list_dir);
                    // drop trailing /
                    if (list_dir[list_dir_len] == '/') {  list_dir[list_dir_len] = 0;  list_dir_len--; }
                    inget_dir = opendir(list_dir);
                    if (inget_dir) {
                        strncpy(inget_name, filename, 128);
                        inget_bytes_left = inget_len = dir_list_len(inget_dir);
                        report("dir list len = %d\n", inget_len);
                        bytes_read = batch_list(fbuff, 512, inget_dir, &endof);
                        inget_bytes_left -= bytes_read;
                        compile_get_response(fbuff, bytes_read, endof);
                        if (endof)  { closedir(inget_dir); inget_dir = NULL; }
                    }
                    else  {
                        [ mammy update: "no can open dir\n" ];
                        obx_outbuff[0] = kOBEXResponseCodeForbiddenWithFinalBit;
                        obx_outbuff[1] = 0;  obx_outbuff[2] = 3;    // total length
                        obx_datalen = 3;
                    }
                }
                else {
                    inget_file = fopen(file_path, "rb");
                    if (inget_file) {
                        strncpy(inget_name, filename, 128);
                        inget_bytes_left = inget_len = file_length(inget_file);
                        bytes_read = fread(fbuff, 1, 512, inget_file);
                        inget_bytes_left -= bytes_read;
                        endof = (inget_bytes_left <= 0);
                        compile_get_response(fbuff, bytes_read, endof);
                        if (endof)  { fclose(inget_file); inget_file = NULL; } // TODO free header list
                    }
                    else {
                        [ mammy update: "file not found\n" ];
                        obx_outbuff[0] = kOBEXResponseCodeNotFoundWithFinalBit;
                        obx_outbuff[1] = 0;  obx_outbuff[2] = 3;    // total length
                        obx_datalen = 3;
                    }
                }
            }
            else  {
                [ mammy update: "no name header\n" ];
                obx_outbuff[0] = kOBEXResponseCodeBadRequestWithFinalBit;
                obx_outbuff[1] = 0;  obx_outbuff[2] = 3;    // total length
                obx_datalen = 3;
            }
        }
        free_obx_hdrs();
    }
    [ outstream write: obx_outbuff maxLength: obx_datalen ];
}

uint32_t put_file_len=0;
uint32_t put_bytes_received=0;
FILE* put_file = NULL;
uint8_t cont[] = { 0x90, 0x00, 0x03 };
uint8_t succ[] = { 0xa0, 0x00, 0x03 };

void write_data_to_file(NSOutputStream* outstream)
{
    uint8_t* bod_ptr;
    uint16_t bodlen;
    bool endof;
    
    if (extract_body(&bod_ptr, &bodlen, &endof)) {
        //hexdump(bod_ptr, bodlen);
        fwrite(bod_ptr, 1, bodlen, put_file);
        put_bytes_received += bodlen;
        if (! (endof || put_bytes_received >= put_file_len)) {
            [ outstream write: cont maxLength: 3 ];    // send continue
        }
        else {
            [ outstream write: succ maxLength: 3  ];    //-> success
            fclose(put_file);  put_file=NULL;  [ mammy update: "put done\n" ];
        }
    }
    else { [ mammy update: "no body\n" ];  fclose(put_file);  put_file=NULL; }
}

void incoming_put(uint8_t* dataPointer, uint16_t dataLength, NSOutputStream* outstream)
{
    uint8_t* filename;
    char file_path[1024];
    struct stat st;

    if (put_file) {
        parse_input(dataPointer, dataLength);
        write_data_to_file(outstream);     // put_file open so save next chunk
        free_obx_hdrs();
    }
    else {
        parse_input(dataPointer, dataLength);
        if (extract_name(&filename)) {
            report("incoming put %s\n", filename);
            strcpy(file_path, download_path);
            //printf("working directory=%s\n", file_path );
            // drop leading / if present
            if (*filename == '/')  strncat(file_path, filename+1, 127);
            else  strncat(file_path, filename, 128);
            report("path=%s\n", file_path);
            if (stat(file_path, &st)) {
               put_bytes_received=0;
               put_file = fopen(file_path, "wb");
               put_file_len = extract_length();
               write_data_to_file(outstream);
            }
            else {
                [ mammy update:"file or dir exists.  REFUSING to overwrite.\n" ];
                obx_outbuff[0] = kOBEXResponseCodeForbiddenWithFinalBit;
                obx_outbuff[1] = 0;  obx_outbuff[2] = 3;    // total length
                [ outstream write: obx_outbuff maxLength: 3 ];
            }
        }
        else  {
            [ mammy update: "no name\n" ];
            obx_outbuff[0] = kOBEXResponseCodeBadRequestWithFinalBit;
            obx_outbuff[1] = 0;  obx_outbuff[2] = 3;    // total length
            [ outstream write: obx_outbuff maxLength: 3 ];
        }
        free_obx_hdrs();
    }
}

void incoming_setpath(uint8_t* dataPointer, uint16_t dataLength, NSOutputStream* outstream)
{
    char *path_name;
    char noo_path[1024];
    bool fail = false;
    int k;
    uint8_t flag = *(dataPointer + 3);
    uint8_t konstant = *(dataPointer + 4);
    
    parse_input(dataPointer, dataLength);
    extract_name(&path_name);
    free_obx_hdrs();
    report("incoming setpath %s.  flag=%d  const=%d.\n",  path_name, flag, konstant);

    // adopt this policy:
    // if flag == goto_parent_dir:
    //      try prune working dir. eg /users/freddy/downloads/ -> /users/freddy/
    // if no path_name do nothing
    // if path_name starts with /  treat as absolute path
    // else append path_name to working directory:  working_dir/ becomes working_dir/path_name/
    if ((flag & 0x01) == 0x01) {
        if (!prune_path())  fail = true;
    }
    if (*path_name) {
        if (*path_name == '/') {
            if (!is_directory(path_name))  fail=true;
            else  strncpy(download_path, path_name, 1024);
        }
        else {
            strncpy(noo_path, download_path, 1024);
            strncat(noo_path, path_name, 1024);
            if (!is_directory(noo_path))  fail = true;
            else  strncpy(download_path, noo_path, 1024);
        }
        k = strlen(download_path)-1;
        if (download_path[k] != '/')  { download_path[++k] = '/';  download_path[++k] = 0; }
        report("working directory: %s\n", download_path);
    }
    if (fail) obx_outbuff[0] = kOBEXResponseCodeForbiddenWithFinalBit;
    else  obx_outbuff[0] = kOBEXResponseCodeSuccessWithFinalBit;
    obx_outbuff[1] = 0;  obx_outbuff[2] = 3;
    [ outstream write: obx_outbuff maxLength: 3 ];
}

void branch(uint8_t* dataPointer, uint16_t dataLength, NSOutputStream* outstream)
{
    char* home;
    // should check if operations pending
    //hexdump(dataPointer, dataLength);
            
    switch (*dataPointer) {
        case kOBEXOpCodeConnect:
            incoming_connect(dataPointer, dataLength, outstream);
            break;
                    
        case kOBEXOpCodeGetWithHighBitSet:
            incoming_get(dataPointer, dataLength, outstream);
            break;
            
        case kOBEXOpCodePut:
        case kOBEXOpCodePutWithHighBitSet:
            incoming_put(dataPointer, dataLength, outstream);
            break;
                    
        case kOBEXOpCodeSetPath:
            // enabling setpath allows access to other directories in the sandbox
            // providing read/write access is granted in capabilities
            // BEWARE: removing sandbox and enabling setpath makes the whole filesystem public
            // uncomment next line to enable setpath
            // incoming_setpath(dataPointer, dataLength, outstream);
            // if allowing setpath, comment out the following 3 lines that send forbidden response
            obx_outbuff[0] = kOBEXResponseCodeForbiddenWithFinalBit;
            obx_outbuff[1] = 0;  obx_outbuff[2] = 3;    // total length
            [ outstream write: obx_outbuff maxLength: 3 ];
            break;
                    
        case kOBEXOpCodeDisconnect:
            [ mammy update: "CLIENT DISCONNECTED\n" ];
            obx_outbuff[0] = kOBEXResponseCodeSuccessWithFinalBit;
            obx_outbuff[1] = 0;  obx_outbuff[2] = 3;    // total length
            [ outstream write: obx_outbuff maxLength: 3 ];
            obx_connected  = false;
                
            home = getenv("HOME");           //  reset working dir
            strncpy(download_path, home, 960);
            strcat(download_path, "/Downloads/");   // /Users/username/Downloads/
            if (!is_directory(download_path))  report("PROBLEM: %s IS NOT A DIRECTORY\n", download_path);
            break;
                                  
        case kOBEXOpCodeAbort:
            //TODO
            break;
            
        default:
            [ mammy update: "unrecognised request\n" ];
            obx_outbuff[0] = kOBEXResponseCodeBadRequestWithFinalBit;
            obx_outbuff[1] = 0;  obx_outbuff[2] = 3;    // total length
            [ outstream write: obx_outbuff maxLength: 3 ];
    }
}

@implementation OBEXserver

-(instancetype) initWithChan:(CBL2CAPChannel *)l2capchan troll: madre
{
    char *home;
    char aka[1024];
    char *p;
    self = [ super init];
    
    _madre = madre;
    _mainrunloop = [ NSRunLoop mainRunLoop ];
    
    _outstream = l2capchan.outputStream;
    [ _outstream scheduleInRunLoop: _mainrunloop forMode: NSDefaultRunLoopMode ];
    _outstream.delegate = self;
       
    _instream = l2capchan.inputStream;
    [_instream scheduleInRunLoop: _mainrunloop forMode: NSDefaultRunLoopMode ];
    _instream.delegate = self;
       
    [ _outstream open ];
    [ _instream open ];
    
    home = getenv("HOME");
    strncpy(download_path, home, 960);
    strcat(download_path, "/Downloads/");   // /Users/username/Downloads/
    if (!is_directory(download_path))  report("PROBLEM: %s IS NOT A DIRECTORY\n", download_path);
    else {
        report("download path = %s\n", download_path);
        strcpy(aka, home);
        p = strstr(aka, "/Library/Containers");
        if (p) { strcpy(p, "/Downloads");  report("             aka  %s\n", aka); }
    }
    return self;
}

-(void) stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
{
    uint8_t buff[2048];
    long n;
    
    if (aStream == _instream) {
        switch (eventCode) {
            case NSStreamEventOpenCompleted:
                [ _madre update: "_instream opened\n" ];
                break;
                
            case NSStreamEventHasBytesAvailable:
                n = [ _instream read: buff maxLength: 2048 ];
                if (n>0)  branch(buff, n, _outstream);
                break;
                
            case NSStreamEventEndEncountered:
                [ _madre update: "_instream end\n" ];
                [ _instream close ];
                [ _instream removeFromRunLoop: _mainrunloop forMode: NSDefaultRunLoopMode ];
                [ _outstream close ];
                [ _outstream removeFromRunLoop: _mainrunloop forMode: NSDefaultRunLoopMode ];
                [ _madre reset ];
                break;
                
            case NSStreamEventErrorOccurred:
                [ _madre update: "_instream error\n" ];
                break;
                
        }
    }
    else if (aStream == _outstream) {
        switch (eventCode) {
            case NSStreamEventOpenCompleted:
                [ _madre update: "_outstream opened\n" ];
                break;
                
            case NSStreamEventEndEncountered:
                [ _madre update: "_outstream end\n" ];
                break;
            
            case NSStreamEventErrorOccurred:
                [ _madre update: "_outstream error\n" ];
                break;
        }
    }
}

@end

