
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

//1GB=260094 Availabel pages for Program Data

//Test1
//	#define ARRAY1_SIZE 260000 //120000
//	#define ARRAY2_SIZE 130000 //120000
//Test2
	#define ARRAY1_SIZE         260080 //260094
	#define ARRAY1_COMPUTE_SIZE 260080 //260094
	#define ARRAY2_SIZE         170000

//ARRAY1
#define ARRAY1_NUM_PAGES ARRAY1_SIZE  
#define ARRAY1_NUM_WORDS (4096/8)*ARRAY1_NUM_PAGES
//ARRAY2
#define ARRAY2_NUM_PAGES ARRAY2_SIZE  
#define ARRAY2_NUM_WORDS (4096/8)*ARRAY2_NUM_PAGES

#define ARRAY1_NUM_COMPUTE_PAGES  ARRAY1_COMPUTE_SIZE
#define ARRAY1_NUM_COMPUTE_WORDS (4096/8)*ARRAY1_NUM_COMPUTE_PAGES
//Array Declarations
uint64_t array2[ARRAY2_NUM_WORDS];
uint64_t array1[ARRAY1_NUM_WORDS];

int main(int argc, char ** argv) {
  uint64_t count=0; 
  uint64_t final_check=0; 
  uint64_t *track_addr=NULL;

  printf("Performing HAWK Test ..\n");
  printf("---------------------------\n");
  printf("Start of Array1=%p\n",array1); 
  printf("End of Array1=%p\n",&array1[ARRAY1_NUM_WORDS]); 
  printf("---------------------------\n");
  printf("Start of Array2=%p\n",array2);
  printf("End of Array2=%p\n",&array2[ARRAY2_NUM_WORDS]); 
  printf("---------------------------\n");

  //Step (1)
  //Initialization and Computation on Array1
  for (int k = 0; k < (ARRAY1_NUM_WORDS); k++) {
	//track_addr=&array1[k];
	//if((uintptr_t)track_addr % 4096==0) {
	if(k%512==0) {
			count++;
			array1[k]=(uint64_t) (count+10);
	}
	else {
			array1[k]=(uint64_t) (0);
	}
  }

  count=0;
  final_check=0;
  printf("Computing on Array1...!\n");
  for (int k = 0; k < (ARRAY1_NUM_COMPUTE_WORDS); k++) {
        final_check+=array1[k];
	if(k%512==0) {
			count++;
	}
	if(k% (50000*512)==0){
		printf("Working on Page %ld to Page %ld..\n",count,count+50000);
	}
  }

  printf("---------------------------\n");
  printf("Computed Value On Array1=%ld\n",final_check);
  printf("---------------------------\n");

  //Ste(2)
  //Initilization and Computation on Array2
  count=0;
  for (unsigned long int k = 0; k < (ARRAY2_NUM_WORDS); k++) {
	//track_addr=&array2[k];
	//if((uintptr_t)track_addr % 4096==0) {
	if(k%512==0) {
			count++;
			array2[k]=(uint64_t) (k+1);
	}
	else {
			array2[k]=(uint64_t) (0);
	}
  }
  count=0;
  final_check=0;
  printf("Computing on Array2...!\n");
  for (unsigned long int k = 0; k < (ARRAY2_NUM_WORDS); k++) {
        final_check+=array2[k];
	if(k%512==0) {
			count++;
	}
	if(k% (50000*512)==0){
		printf("Working on Page %ld to Page %ld..\n",count,count+50000);
	}
  } 
  printf("---------------------------\n");
  printf("Computed Value On Array2=%ld\n", final_check);
  printf("---------------------------\n");

  //Step(3)
  //Recompute on Array1
  count=0; 
  final_check=0;
  printf("Re-Computing on Array1...!\n");
  for (int k = 0; k < (ARRAY1_NUM_COMPUTE_WORDS); k++) {
        final_check+=array1[k];
	if(k%512==0) {
        	count++;
	}
	if(k% (50000*512)==0){
		printf("Working on Page %ld to Page %ld..\n",count,count+50000);
	}
  } 
  printf("---------------------------\n");
  printf("Re-Computed Value On Array1=%ld\n",final_check);
  printf("---------------------------\n");
  printf("Completed HAWK Test!\n");
  return 0;
}


