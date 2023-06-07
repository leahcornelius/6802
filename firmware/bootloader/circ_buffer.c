// A circular buffer implementation in small C for the 6802

#define BUFFER_START_ADDR 0x0000 // Start of buffer in memory (inclusive)
#define BUFFER_END_ADDR 0x0100 // End of buffer in memory (exclusive)
#define BUFFER_SIZE (BUFFER_END_ADDR - BUFFER_START_ADDR)

unsigned char buffer[BUFFER_SIZE];
unsigned char *buffer_head = buffer; // Pointer to next byte to be read from buffer
unsigned char *buffer_tail = buffer; // Pointer to next byte to be written to buffer

void append_char(unsigned char c) {
    *buffer_head = c;
    buffer_head++;
    if ((unsigned short)buffer_head == BUFFER_END_ADDR) {
        buffer_head = BUFFER_START_ADDR;
    }
}

int main() {
	unsigned char tester = 0x0A;
	append_char(tester);
	return 1;
}
