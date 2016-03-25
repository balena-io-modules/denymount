/*
 * Copyright 2016 Resin.io
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import <CoreFoundation/CoreFoundation.h>
#import <DiskArbitration/DiskArbitration.h>

void DMDenyMount(DASessionRef session, const char *diskName);
DADissenterRef DMMountApprovalCallback(DADiskRef disk, void *context);
bool DMAreDisksEqual(DADiskRef disk1, DADiskRef disk2);
DADiskRef DMGetWholeDisk(DADiskRef disk);

volatile bool running = true;

int main(int argc, const char *argv[]) {
  if (argc != 2) {
    fprintf(stderr, "Usage: %s diskName\n", argv[0]);
    return EXIT_FAILURE;
  }

  @autoreleasepool {
    // Create a serial queue to schedule callbacks on
    dispatch_queue_t queue = dispatch_queue_create("denymount", DISPATCH_QUEUE_SERIAL);

    // Run loops aren't signal-safe, so setup dispatch sources to handle
    // INT and TERM signals and toggle our `running` flag
    void(^terminationHandler)(void) = ^{ running = false; };
    dispatch_source_t sigintSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_SIGNAL, SIGINT, 0, queue);
    dispatch_source_t sigtermSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_SIGNAL, SIGTERM, 0, queue);
    dispatch_source_set_event_handler(sigintSource, terminationHandler);
    dispatch_source_set_event_handler(sigtermSource, terminationHandler);

    // Setup the disk arbitration session
    DASessionRef session = DASessionCreate(kCFAllocatorDefault);
    DMDenyMount(session, argv[1]);
    DASessionSetDispatchQueue(session, queue);

    // Start signal sources to listen for signals
    dispatch_resume(sigintSource);
    dispatch_resume(sigtermSource);

    // Run the run loop to service GCD
    while (running) {
      @autoreleasepool {
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 1, true);
      }
    }

    // Cleanup
    dispatch_source_cancel(sigintSource);
    dispatch_source_cancel(sigtermSource);
    DASessionSetDispatchQueue(session, NULL);
    CFRelease(session);
    session = NULL;
  }

  return EXIT_SUCCESS;
}

void DMDenyMount(DASessionRef session, const char *diskName) {
  printf("Intercepting %s...\n", diskName);
  DADiskRef disk = DADiskCreateFromBSDName(kCFAllocatorDefault, session, diskName);
  DARegisterDiskMountApprovalCallback(session,
                                      kDADiskDescriptionMatchVolumeMountable,
                                      DMMountApprovalCallback,
                                      (void *)disk);
}

bool DMAreDisksEqual(DADiskRef disk1, DADiskRef disk2) {
  return strcmp(DADiskGetBSDName(disk1), DADiskGetBSDName(disk2)) == 0;
}

DADiskRef DMGetWholeDisk(DADiskRef disk) {
  DADiskRef whole = DADiskCopyWholeDisk(disk);

  if (whole) {
    return whole;
  }

  return disk;
}

DADissenterRef DMMountApprovalCallback(DADiskRef disk, void *context) {
  DADissenterRef dissenter = NULL; // allow by default
  DADiskRef wholeDisk = DMGetWholeDisk(disk);
  DADiskRef watchedDisk = context;

  printf("Request to mount volume %s... ", DADiskGetBSDName(wholeDisk));

  if (DMAreDisksEqual(wholeDisk, watchedDisk)) {
    printf("DENY\n");
    dissenter = DADissenterCreate(kCFAllocatorDefault, kDAReturnExclusiveAccess, NULL);
    running = false;
  } else {
    printf("OK");
    dissenter = NULL;
  }

  if (wholeDisk) {
    CFRelease(wholeDisk);
    wholeDisk = NULL;
  }

  fflush(stderr);

  return dissenter;
}
