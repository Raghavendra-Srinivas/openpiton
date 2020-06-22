//HAWK TEST
#include <stdio.h>

#define HACD_BASE    0xfff5100000ULL

//For DV
#define HPPA_BASE 0xfff6400000ULL
#define FOURKB 0x1000

//For FPGA
//#define HPPA_BASE 0xC0400000ULL 
//#define FOURKB 0x1000



int main(int argc, char ** argv) {
  uint64_t *addr;
  uint64_t *addr_base;

  volatile uint32_t val;

  printf("\nHello World ..!\n");
  printf("Performing HAWK Test ..\n");
  for (int k = 0; k < 1; k++) {
    // assemble number and print
    printf("Hello world, I am HART %d! Counting (%d of 32)...\n", argv[0][0], k);
  }

  //Read from HPPAs 
  //(1): At T1, WRITE HPPA1
  addr_base = (uint64_t*)(HPPA_BASE+(0*FOURKB)); //hppa1
  for (int i = 0; i < 16*64; i++) {
  	addr = (uint64_t*)(addr_base+(i*4)); 
	*addr = (uint32_t) i;
  }
  printf("HACD: Accesing Memory on 0x%llx, data = 0x%llx\n",addr_base,*addr_base+(16*4)*16);

  //(2): At T2, WRITE HPPA2
  addr_base = (uint64_t*)(HPPA_BASE+(1*FOURKB)); //hppa2
  for (int i = 0; i < 16*64; i++) {
  	addr = (uint64_t*)(addr_base+(i*4)); //hppa2
	if (i<16*16) {
	  *addr = (uint32_t) 0x0; //first chunk with zero
	}
	else {
	  *addr = (uint32_t) i; // other 3 chunks with non-zero
	}
  }
  printf("HACD: Accesing Memory on 0x%llx, data = 0x%llx\n",addr_base,*addr_base+(16*4)*16);

  //(3): At T3, WRITE HPPA3
  addr_base = (uint64_t*)(HPPA_BASE+(2*FOURKB)); //hppa3
  for (int i = 0; i < 16*64; i++) {
  	addr = (uint64_t*)(addr_base+(i*4)); //hppa3
	if (i<16*16) {
	  *addr = (uint32_t) 0x0; //first chunk with zero
	}
	else {
	  *addr = (uint32_t) i; // other 3 chunks with non-zero
	}
  }
  printf("HACD: Accesing Memory on 0x%llx, data = 0x%llx\n",addr_base,*addr_base+(16*4)*16); 

  //(4): At T3, WRITE HPPA4
  addr_base = (uint64_t*)(HPPA_BASE+(3*FOURKB)); //hppa3
  for (int i = 0; i < 16*64; i++) {
  	addr = (uint64_t*)(addr_base+(i*4)); //hppa3
	if (i<16*16) {
	  *addr = (uint32_t) 0x0; //first chunk with zero
	}
	else {
	  *addr = (uint32_t) i; // other 3 chunks with non-zero
	}
  }
  printf("HACD: Accesing Memory on 0x%llx, data = 0x%llx\n",addr_base,*addr_base+(16*4)*16);


  //(5): At T5, READ HPPA5
  //This access should trigger COMPRESSION of VICTIM UNCOMPRESSED PAGEs to make FREE page - PPA1 is victim now
  printf("Accessing Non-Guaranteed Page\n");
  addr = (uint64_t*)(HPPA_BASE+(4*FOURKB)); //hppa5
  printf("HACD: Accesing Memory on 0x%llx, data = 0x%llx\n",addr,*addr);

  //(6): At T6, READ HPPA2
  //Access compressed page- This should trigger COMPRESSION of another 
  //VICTIM UNCOMPRESSED PAGE to free the page for hppa2
  printf("Accessing Compressed Page\n");
  addr = (uint64_t*)(HPPA_BASE+(1*FOURKB)); //hppa1
  printf("HACD: Accesing Memory on 0x%llx, data = 0x%llx\n",addr,*addr);


  printf("HAWK Test Done!..\n");

  return 0;
}

