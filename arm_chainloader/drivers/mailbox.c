#include <hardware.h>

void mailbox_write_word(void* data) {
    while(mmio_read32(ARM_0_MAIL1_STA) & ARM_MS_FULL);
    mmio_write32(ARM_0_MAIL1_WRT, data);
}
