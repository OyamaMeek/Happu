#import "include/ShuNetwork.h"
#import <net/if.h>
#import <sys/socket.h>
#import <sys/sockio.h>
#import <sys/ioctl.h>
#import <unistd.h>

int ShuInterfaceFunctionalType(const char *name) {
    int descriptor = socket(AF_INET, SOCK_DGRAM, 0);
    if (descriptor < 0) return -1;
    struct ifreq request = {0};
    strlcpy(request.ifr_name, name, sizeof(request.ifr_name));
    int result = ioctl(descriptor, SIOCGIFFUNCTIONALTYPE, &request);
    close(descriptor);
    return result == 0 ? (int)request.ifr_ifru.ifru_functional_type : -1;
}
