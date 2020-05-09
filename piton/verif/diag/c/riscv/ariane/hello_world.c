//HAWK TEST

#include <stdio.h>

#define HACD_BASE    0xfff5100000ULL
#define HPPA_BASE 0xfff6400000ULL
#define FOURKB 0x1000
#define PLIC_BASE    0xfff1100000ULL

#define IRQ_ENABLE_TARGET1 0x0002000 //Per IrQ 1 bit from lsb = 'b100 for hawk
#define IRQ_ENABLE_TARGET2 0x0002080 //

#define IRQ_PRIORITY_SRC0 0x0000000
#define IRQ_PRIORITY_SRC1 0x0000004
#define IRQ_PRIORITY_SRC2 0x0000008 //for hawk -set it to 3'b111
#define IRQ_PRIORITY_SRC3 0x000000C //for hawk -set it to 3'b111

int main(int argc, char ** argv) {


  printf("Hello World ..!\n");
  printf("Performing HAWK Test ..\n");
  uint64_t *addr;
  volatile uint32_t val;
 
  addr = (uint32_t*)(PLIC_BASE+IRQ_ENABLE_TARGET1);
  val = *addr;
  printf("PLIC TARGET1 IRQ Enable before 0x%llx, data = 0x%x\n",addr,val);
  val = val | 0x8;
  *addr=val; 
  printf("PLIC TARGET1 IRQ Enable after 0x%llx, data = 0x%x\n",addr,*addr);

  addr = (uint32_t*)(PLIC_BASE+IRQ_PRIORITY_SRC3);
  val = *addr;
  printf("PLIC PRIORITY SRC3 before 0x%llx, data = 0x%x\n",addr,val);
  val = val | 0x7;
  *addr=val; 
  printf("PLIC PRIORITY SRC3 after 0x%llx, data = 0x%x\n",addr,*addr);

  //Assert Interrupt
  addr = (uint64_t*)(HACD_BASE);
  printf("HACD: Cntrl result = 0x%016x\n",*addr);
  printf("Writing Control Register.\n");
  *addr = (uint32_t) 0x1;
  printf("HACD: Cntrl result = 0x%016x\n",*addr);
 
/*
  addr = (uint32_t*)(PLIC_BASE+IRQ_ENABLE_TARGET2);
  val = *addr;
  printf("PLIC TARGET2 IRQ Enable before 0x%llx, data = 0x%x\n",addr,val);
  val = val | 0xF;
  *addr=val; 
  printf("PLIC TARGET2 IRQ Enable after 0x%llx, data = 0x%x\n",addr,*addr);


  addr = (uint32_t*)(PLIC_BASE+IRQ_PRIORITY_SRC0);
  val = *addr;
  printf("PLIC PRIORITY SRC0 before 0x%llx, data = 0x%x\n",addr,val);
  val = val | 0x7;
  *addr=val; 
  printf("PLIC PRIORITY SRC0 after 0x%llx, data = 0x%x\n",addr,*addr);

  addr = (uint32_t*)(PLIC_BASE+IRQ_PRIORITY_SRC1);
  val = *addr;
  printf("PLIC PRIORITY SRC1 before 0x%llx, data = 0x%x\n",addr,val);
  val = val | 0x7;
  *addr=val; 
  printf("PLIC PRIORITY SRC1 after 0x%llx, data = 0x%x\n",addr,*addr);

  addr = (uint32_t*)(PLIC_BASE+IRQ_PRIORITY_SRC2);
  val = *addr;
  printf("PLIC PRIORITY SRC2 before 0x%llx, data = 0x%x\n",addr,val);
  val = val | 0x7;
  *addr=val; 
  printf("PLIC PRIORITY SRC2 after 0x%llx, data = 0x%x\n",addr,*addr);
 */

 


  /*  
  //Read from HPPAs 
  //(1): At T1, READ HPPA1
  addr = (uint64_t*)(HPPA_BASE+(0*FOURKB)); //hppa1
  printf("HACD: Accesing Memory on 0x%llx, data = 0x%llx\n",addr,*addr);

  //(2): At T2, READ HPPA2
  addr = (uint64_t*)(HPPA_BASE+(1*FOURKB)); //hppa2
  printf("HACD: Accesing Memory on 0x%llx, data = 0x%llx\n",addr,*addr);

  //(3): At T3, READ HPPA3
  addr = (uint64_t*)(HPPA_BASE+(2*FOURKB)); //hppa3
  printf("HACD: Accesing Memory on 0x%llx, data = 0x%llx\n",addr,*addr);

  //(4): At T4, READ HPPA4
  addr = (uint64_t*)(HPPA_BASE+(3*FOURKB)); //hppa4
  printf("HACD: Accesing Memory on 0x%llx, data = 0x%llx\n",addr,*addr);


  //(5): At T5, READ HPPA5
  //This access should trigger COMPRESSION of VICTIM UNCOMPRESSED PAGEs to make FREE page - PPA1 is victim now
  printf("Accessing Non-Guaranteed Page\n");
  addr = (uint64_t*)(HPPA_BASE+(4*FOURKB)); //hppa5
  printf("HACD: Accesing Memory on 0x%llx, data = 0x%llx\n",addr,*addr);

  //(6): At T6, READ HPPA1
  //Access compressed page- This should trigger COMPRESSION of another 
  //VICTIM UNCOMPRESSED PAGE to free the page for hppa1
  printf("Accessing Compressed Page\n");
  addr = (uint64_t*)(HPPA_BASE+(0*FOURKB)); //hppa1
  printf("HACD: Accesing Memory on 0x%llx, data = 0x%llx\n",addr,*addr);

  */
  printf("HAWK Test Done!..\n");

  return 0;
}

