
//HAWK TEST
//Verify Zspage compaction with access irregulalry. 3 ZsPages
//Needs decompression count of at-leat 2 with threshold count of 2 to trigger compaction
//
#include <stdio.h>

#define HAWK_REG_BASE  0xfff5100000ULL
#define CMPT_TH_OFFSET  0x8

//For DV
#define HPPA_BASE 0xfff6400000ULL
#define FOURKB 0x1000

//For FPGA
//#define HPPA_BASE 0xC0400000ULL 
//#define FOURKB 0x1000

#define LINE_SIZE 64
#define POINTER_SIZE 8

#define LST_ENTRY_CNT 12

int main(int argc, char ** argv) {
  uint64_t *addr;
  uint64_t *addr_base;

  volatile uint32_t val;

  printf("Performing HAWK Test ..\n");

  addr = (uint64_t*)(HAWK_REG_BASE+CMPT_TH_OFFSET);
  printf("HAWK CMPT_TH : Default Value = 0x%016x\n",*addr);
  printf("HAWK CMPT_TH : Writing Value=0x3\n");
  *addr = (uint32_t) 0x3;
  printf("HAWK CMPT_TH: Read back Value = 0x%016x\n",*addr);

  //Read from HPPAs 
  //(1): At T1, WRITE HPPA1
  //addr_base = (uint64_t*)(HPPA_BASE+(0*FOURKB)); //hppa1
  //for (int i = 0; i < 64; i++) {
  //	addr = (uint64_t*)(addr_base+i*(LINE_SIZE/POINTER_SIZE)); 
  //      *addr = (uint64_t) (i+1);
  //}
  //printf("HACD: Accesing Memory on 0x%llx, data = 0x%llx\n",addr_base,*addr_base);
  //addr_base = (uint64_t*)(HPPA_BASE+(1*FOURKB)); //hppa1
  //for (int i = 0; i < 64; i++) {
  //	addr = (uint64_t*)(addr_base+i*(LINE_SIZE/POINTER_SIZE)); 
  //      *addr = (uint64_t) (i+1);
  //}

  for(int j=0;j<LST_ENTRY_CNT;j++) {
  addr_base = (uint64_t*)(HPPA_BASE+(j*FOURKB)); //hppa2
  for (int i = 0; i < 64; i++) {
  	addr = (uint64_t*)(addr_base+i*(LINE_SIZE/POINTER_SIZE)); 
        if (i<1) {
          *addr = (uint64_t) addr; //(i+1); //first chunk with non-zero
        }
        else {
          *addr = (uint64_t) 0x0; // other 3 chunks with zero
        }
  }
  //printf("HACD: Accesing Memory on 0x%llx, data = 0x%llx\n",addr_base,*(addr_base+(16*(LINE_SIZE/POINTER_SIZE))));
  //printf("HACD: Accesing Memory on 0x%llx, data = 0x%llx\n",addr_base,*(addr_base));
 }

 //(5): At T5, READ HPPA5
 for(int k=LST_ENTRY_CNT;k<LST_ENTRY_CNT+5;k++) {
 	//This access should trigger COMPRESSION of VICTIM UNCOMPRESSED PAGEs to make FREE page 
 	printf("Accessing Non-Guaranteed Page=%d\n",k);
 	addr = (uint64_t*)(HPPA_BASE+(k*FOURKB)); //hppa5
 	printf("HACD: Accesing Memory on 0x%llx, data = 0x%llx\n",addr,*addr);
 }

//Trigger 3 decompressions to trigger Zspage compaction
 printf("Accessing Compressed Page\n");
 addr = (uint64_t*)(HPPA_BASE+(0*FOURKB)); //hppa0
 printf("HACD: Accesing Memory on 0x%llx, data = 0x%llx\n",addr,*addr);

 printf("Accessing Compressed Page\n");
 addr = (uint64_t*)(HPPA_BASE+(1*FOURKB)); //hppa1
 printf("HACD: Accesing Memory on 0x%llx, data = 0x%llx\n",addr,*addr);

 printf("Accessing Compressed Page\n");
 addr = (uint64_t*)(HPPA_BASE+(2*FOURKB)); //hppa2
 printf("HACD: Accesing Memory on 0x%llx, data = 0x%llx\n",addr,*addr);

//Below access should be in pending till compaction is completed
 printf("Accessing Compressed Page- ZsPage pagecompation should free up one page \n");
 addr = (uint64_t*)(HPPA_BASE+(3*FOURKB)); //hppa3
 printf("HACD: Accesing Memory on 0x%llx, data = 0x%llx\n",addr,*addr);

 printf("HAWK Test Done!..\n");

 return 0;
}

