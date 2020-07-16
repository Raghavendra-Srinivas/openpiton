
//HAWK TEST

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

#define HACD_BASE    0xfff5100000ULL

//For FPGA
#define HPPA_BASE 0x80000000ULL //0x80100000ULL
#define FOURKB 0x1000

#define NUM_PAGES 260094 //262144 are available PPAs and One page is used by instruction on starting region,so 290094 shuld make Free list empty

#define NUM_WORDS (4096/8)*NUM_PAGES //40000
#define ARRAY2_NUM_WORDS (4096/8)*173000   //173396
#define HPPA_BASE_GT_1GB 0xC0000000ULL

//uint64_t compute_array[NUM_WORDS];
uint64_t tmp[NUM_WORDS];
uint64_t array2[ARRAY2_NUM_WORDS];


int main(int argc, char ** argv) {
  //uint64_t *array_2;
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
  }

  uint64_t count=0; 
  uint64_t final_check=0; 
  uint64_t final_check1=0; 
/*
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
	      			tmp[(k*512)+8*i+j]=(uint64_t) (0);
                		final_check+=tmp[(k*512)+8*i+j];
			}
		}
	}/
	 
	count++;
	
	if(k%512==0) {
  			printf("Address of this page=%x\n ,count=%d\n",&tmp[k],count);
	}
  }
*/

	printf("Address of Array 1=%x\n",&tmp);
	printf("Address of Array 2=%x\n",&array2);

  //Initialization
  for (int k = 0; k < (NUM_WORDS); k++) {
	
	if(k%512==0) {
			count++;
			tmp[k]=(uint64_t) (k+1);
			//if(&tmp[k]>0xC0000000) {
  			//	printf("Address of this page=%x\n ,count=%d\n",&tmp[k],count);
			//}
	}
	else {
			tmp[k]=(uint64_t) (0);
	}
                	final_check+=tmp[k];
  }
 
  

  printf("Computed Value On Initialized Space=%ld\n",final_check);
  printf("Page count=%ld\n",count);

  printf("Number of First Array Elements Initialized=>Count=%ld\n",count);

  count=0;
  final_check1=0;
  for (int k = 0; k < (ARRAY2_NUM_WORDS); k++) {
	
	if(k%512==0) {
			count++;
			array2[k]=(uint64_t) (k+1);
			//if(count>10000) {
			//if(&array2[k]>0xC0000000) {
  			   //printf("Address of this page=%x\n ,count=%d\n",&array2[k],count);
			//}
	}
	else {
			array2[k]=(uint64_t) (k+256);
	}
                	final_check1+=array2[k];
  }

  printf("Final Computed Value On Extra Space=%ld\n", final_check1);
  printf("Extra Space Access Page Count While Computing=%ld\n",count);

  printf("HAWK Test Done!\n");
  
  return 0;
}

