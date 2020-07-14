
//HAWK TEST

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

#define HACD_BASE    0xfff5100000ULL

//For FPGA
#define HPPA_BASE 0x80000000ULL //0x80100000ULL
#define FOURKB 0x1000

#define NUM_PAGES 260094 //290096 are available PPAs and One page is used by instruction on starting region,so 290095 shuld make Free list empty
#define NUM_WORDS (4096/8)*NUM_PAGES //40000
#define ARRAY2_NUM_WORDS 10 //(4096/8)*130000
#define HPPA_BASE_GT_1GB 0xC0000000ULL

//uint64_t compute_array[NUM_WORDS];
uint64_t tmp[NUM_WORDS];


int main(int argc, char ** argv) {
  uint64_t *array_2;
  //uint64_t *tmp=&compute_array;
  volatile uint32_t val;

  //uint64_t tmp[NUM_WORDS];

  //uint64_t *tmp;
  //tmp=(uint64_t *) malloc(NUM_WORDS);
  printf("\nHello World ..!\n");
  printf("Performing HAWK Test ..\n");

  for (int k = 0; k < 1; k++) {
    // assemble number and print
    printf("Hello world, I am HART %d! Counting (%d of 32)...\n", argv[0][0], k);
    printf("Address of Computng Array=%x...\n",&tmp);
  }

  uint64_t count=0; 
  uint64_t final_check=0; 
  //Initialization
  for (int k = 0; k < (NUM_PAGES); k++) {
	//for each cache line of page, initilizaze very first cache line to be non-zero
	for(int i=0;i<64;i++){
		if(i==0) {
			for(int j=0;j<8;j++) {
				tmp[(k*512)+8*i+j]=(uint64_t) (k+argv[0][0]);
                		final_check+=tmp[(k*512)+8*i+j];
			}
		} else {
			for(int j=0;j<8;j++) {
	      			tmp[(k*512)+8*i]=(uint64_t) (0);
                		final_check+=tmp[(k*512)+8*i+j];
			}
		}
	}
	count++;
	
	if(k%512==0) {
  			printf("Address of this page=%x\n ,count=%d\n",&tmp[k],count);
	}
  }
  printf("Computed Value On Initialized Space=%ld,Page count=%ld\n",final_check,count);

  printf("Number of First Array Elements Initialized=>Count=%ld\n",count);
  array_2 = (uint64_t*)(HPPA_BASE_GT_1GB);
  printf("Address of Second Array =>%0x\n",array_2);
  printf("Initializing and Computing on Second Array \n");
  count=0;
  final_check=0;
  //Initialization
  for (int k = 0; k < (ARRAY2_NUM_WORDS); k++) {
	//if(k%512==0) {
  	array_2 = (uint64_t*)(HPPA_BASE_GT_1GB+k); //hppa1
		if(k==0) {
			if(argc!=0) {
				*array_2=(uint64_t) (32+argv[0][0]);
			} else {
			 	 printf("ARG NOT found");
			} 
		} else {
	      			*array_2=(uint64_t) (k+argv[0][0]+10);
		}
	count++;
                final_check+=*array_2+k+256;
  		//printf("K Value =%d\n",k);
//	}
   //}
 } 

  printf("HAWK Test Done!\n..Final Computed Value On Extra Space=%ld, Extra Space Access Page Count While Computing=%ld\n",final_check,count);
  return 0;
}

