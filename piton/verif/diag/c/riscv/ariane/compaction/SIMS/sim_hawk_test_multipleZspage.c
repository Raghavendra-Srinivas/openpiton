//For this test to work, design should support minimum 8 LST entries and 8 ATT Entries
//
//
//
//
//HAWK TEST
#include <stdio.h>

#define HACD_BASE    0xfff5100000ULL

//For DV
#define HPPA_BASE 0xfff6400000ULL
#define FOURKB 0x1000

//For FPGA
//#define HPPA_BASE 0xC0400000ULL 
//#define FOURKB 0x1000

#define LINE_SIZE 64
#define POINTER_SIZE 8

// 8 List Entries
// 12 HPPA
//Any access >HPPA7 triggers compression
//
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
  //(1):  WRITE HPPA1
  addr_base = (uint64_t*)(HPPA_BASE+(0*FOURKB)); //hppa1
  for (int i = 0; i < 64; i++) {
  	addr = (uint64_t*)(addr_base+i*(LINE_SIZE/POINTER_SIZE)); 
	*addr = (uint64_t) (i+1);
  }
  //printf("HACD: Accesing Memory on 0x%llx, data = 0x%llx\n",addr_base,*addr_base);

  //(2): WRITE HPPA2-HPPA7 
  for(int j=1;j<8;j++) {
  addr_base = (uint64_t*)(HPPA_BASE+(j*FOURKB)); //hppa2
  for (int i = 0; i < 64; i++) {
  	addr = (uint64_t*)(addr_base+i*(LINE_SIZE/POINTER_SIZE)); 
	if (i<16) {
	  *addr = (uint64_t) (i+1); //first chunk with zero
	}
	else {
	  *addr = (uint64_t) 0x0; // other 3 chunks with non-zero
	}
  }
  //printf("HACD: Accesing Memory on 0x%llx, data = 0x%llx\n",addr_base,*(addr_base+(16*(LINE_SIZE/POINTER_SIZE))));
 }

 //(5) Read Non-Gauranteed Pages - HPPA8 to HPPA12
 for(int k=8;k<12;k++) {
 	//This access should trigger COMPRESSION of VICTIM UNCOMPRESSED PAGEs to make FREE page 
 	printf("Accessing Non-Guaranteed Page=%d\n",k);
 	addr = (uint64_t*)(HPPA_BASE+(k*FOURKB)); //hppa5
 	printf("HACD: Accesing Memory on 0x%llx, data = 0x%llx\n",addr,*addr);
 }
// //(5): At T5, READ HPPA5
// for(int k=0;k<260;k++) {
// 	//This access should trigger COMPRESSION of VICTIM UNCOMPRESSED PAGEs to make FREE page 
// 	printf("Accessing Guaranteed Page=%d\n",k);
// 	addr = (uint64_t*)(HPPA_BASE+(k*FOURKB)); //hppa5
// 	printf("HACD: Accesing Memory on 0x%llx, data = 0x%llx\n",addr,*addr);
// }

/*
 //(6): At T6, READ HPPA2
 //Access compressed page- This should trigger COMPRESSION of another 
 //VICTIM UNCOMPRESSED PAGE to free the page for hppa2
 printf("Accessing Compressed Page\n");
 addr = (uint64_t*)(HPPA_BASE+(1*FOURKB)); //hppa1
 printf("HACD: Accesing Memory on 0x%llx, data = 0x%llx\n",addr,*addr);
*/

 printf("HAWK Test Done!..\n");
 return 0;

}

