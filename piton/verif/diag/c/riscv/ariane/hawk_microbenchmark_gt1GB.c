
//HAWK TEST

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

#define HACD_BASE    0xfff5100000ULL

//For FPGA
#define HPPA_BASE 0x80000000ULL //0x80100000ULL
#define FOURKB 0x1000

#define NUM_PAGES 260094 //259000 //262144 are available PPAs and One page is used by instruction on starting region,so 260094 shuld make Free list empty

#define NUM_WORDS (4096/8)*NUM_PAGES //40000

///for 1.66GB
#define ARRAY2_NUM_WORDS (4096/8)*173394 //120000 //173000 //(working)   //173396(maximum possible)

//for 2.98GB
//#define ARRAY2_NUM_WORDS (4096/8)*200000 //120000 //173000 //(working)   //173396(maximum possible)

#define FIRST_ARRAY_REACCESS_NUM_WORDS NUM_WORDS //-50000 //(4096/8)*40000 //NUM_WORDS //(4096/8)*10000



//#define HPPA_BASE_GT_1GB 0xC0000000ULL


//uint64_t compute_array[NUM_WORDS];
uint64_t array2[ARRAY2_NUM_WORDS];
uint64_t tmp[NUM_WORDS];


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
  uint64_t final_check3=0; 
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
   uint64_t *track_addr=NULL,*page_aligned_array_addr=NULL;
  final_check3=0;
  count=0;  
  //Initialization
  for (int k = 0; k < (NUM_WORDS); k++) {
	track_addr=&tmp[k];
	//if(k%512==0) {
	if((uintptr_t)track_addr % 4096==0) {
			count++;
			//tmp[k]=(uint64_t) (k+1);
			tmp[k]=(uint64_t) (count+10);
                	final_check3+=tmp[k];
			//if(&tmp[k]>0xC0000000) {
  			//	printf("Address of this page=%x\n ,count=%d\n",&tmp[k],count);
			//}
	}
	else {
			tmp[k]=(uint64_t) (0);
	}
                	//final_check+=tmp[k];
  }
 
  //final_check3=0;
  //count=0;  
  //for (int k = 0; k < (FIRST_ARRAY_REACCESS_NUM_WORDS); k++) {
  //      track_addr=&tmp[k];
  //      //if(k%512==0) {
  //      //if(track_addr % 4096==0) {
  //      if((uintptr_t)track_addr % 4096==0) {
  //      		count++;
  //              	final_check3+=tmp[k];
  //      }
  //} 
  printf("Computed Value On First Array Before compression=%ld\n",final_check3);
  printf(" Conisdered Page count on First Array=%ld\n",count);
 

  //printf("Computed Value On Initialized Space=%ld\n",final_check);
  //printf("Page count=%ld\n",count);

  printf("Number of First Array Elements Initialized=>Count=%ld\n",count);




  count=0;
  final_check1=0;
  for (unsigned long int k = 0; k < (ARRAY2_NUM_WORDS); k++) {
	
	if(k%512==0) {
			count++;
			array2[k]=(uint64_t) (k+1);
			//if(count>10000) {
			//if(&array2[k]>0xC0000000) {
  			   //printf("Address of this page=%x\n ,count=%d\n",&array2[k],count);
			//}
	}
	else {
			array2[k]=(uint64_t) (0);  //(k+256);
	}
                	//final_check1+=array2[k];
  }







  count=0; 
  final_check1=0; 
  for (int k = 0; k < (ARRAY2_NUM_WORDS); k++) {
        if(k%512==0) {
        		count++;
        }
                	final_check1+=array2[k];
  }
  printf("Final Computed Value On Extra Space=%ld\n", final_check1);
  printf("Extra Space Access Page Count While Computing=%ld\n",count);
 
  //final_check3=0;
  //count=0;  
  //for (int k = 0; k < (FIRST_ARRAY_REACCESS_NUM_WORDS); k++) {
  //      
  //      if(k%512==0) {
  //      		count++;
  //      		if(tmp[k]!=(uint64_t) (k+1)) {
  //				printf("After Decompression - PAGE INTEGRITY FAIL on Page Number-%ld\n, Element Index=%ld\n, Expected==%ld\n, Observed =%ld\n",count,k, (k+1),tmp[k]);
  //      		
  //      		}
  //      } else {
  //      		if(tmp[k]!=(uint64_t) 0) {
  //				printf("After Decompression - PAGE INTEGRITY FAIL on Page Number-%ld\n, Element Index=%ld\n, Expected==%ld\n, Observed =%ld\n",count,k,0,tmp[k]);
  //      		}
  //      }
  //              	final_check3+=tmp[k];
  //} 
  //printf("Computed Value On First Array After Decompression=%ld\n",final_check3);
  //printf("Decompressed Page count=%ld\n",count);


  final_check3=0;
  count=0; 
  _Bool  page_start_addr_capture=0;
  for (int k = 0; k < (FIRST_ARRAY_REACCESS_NUM_WORDS); k++) {
	track_addr=&tmp[k];
        //if(k%512==0) {
	//if(track_addr % 4096==0) {
	if((uintptr_t)track_addr % 4096==0) {
			page_aligned_array_addr=track_addr;
			page_start_addr_capture=1;
        		count++;
        		if(tmp[k]!=(uint64_t) (count+10)) {
  				printf("Aligned Page Address - PAGE INTEGRITY FAIL on Page Number-%ld\n, Element Index=%ld\n, Expected==%ld\n, Observed =%ld\n",count,k, (k+1),tmp[k]);
        		
        		}
                	final_check3+=tmp[k];
  			//printf("First Array decompression Track Addr=%x\n, Page count =%ld\n",track_addr , count);
        //} else if (track_addr > page_aligned_array_addr && page_start_addr_capture) {
        } //else if (page_start_addr_capture && (track_addr<(page_aligned_array_addr+(4096/8)))) {

        //		if(tmp[k]!=(uint64_t) 0) {
  	//			printf( "PAGE INTEGRITY FAIL on Page Number-%ld\n, Track Addr=%x\n, Expected==%ld\n, Observed =%ld\n",track_addr,k,0,tmp[k]);
        //		}

	//}
  } 
  printf("Computed Value On First Array After Decompression=%ld\n",final_check3);
  printf(" Conisdered Page count on First Array=%ld\n",count);

  //count=0; 
  //final_check1=0; 
  //for (int k = 0; k < (ARRAY2_NUM_WORDS); k++) {
  //      if(k%512==0) {
  //      		count++;
  //      }
  //              	final_check1+=array2[k];
  //}
  //printf("Final Computed Value On Extra Space=%ld\n", final_check1);
  //printf("Extra Space Access Page Count While Computing=%ld\n",count);

 
  printf("HAWK Test Done!\n");
  
  return 0;
}

