//
//  FDExecutable.m
//  ARMSerialWireDebug
//
//  Created by Denis Bohm on 4/26/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import "FDError.h"
#import "FDExecutable.h"

#include <dwarf.h>
#include <gelf.h>
#include <libelf.h>
#include <libdwarf.h>

struct srcfilesdata {
    char **srcfiles;
    Dwarf_Signed srcfilescount;
    int srcfilesres;
};


@implementation FDExecutableSymbol
@end

@implementation FDExecutableFunction
@end

@implementation FDExecutableSection
@end

@interface FDExecutable ()
@end

@implementation FDExecutable

- (id)init
{
    if (self = [super init]) {
        _sections = [NSArray array];
        _functions = [NSMutableDictionary dictionary];
        _globals = [NSMutableDictionary dictionary];
    }
    return self;
}

- (BOOL)read_cu_list:(Dwarf_Debug)dbg error:(NSError **)error
{
    Dwarf_Unsigned cu_header_length = 0;
    Dwarf_Half version_stamp = 0;
    Dwarf_Unsigned abbrev_offset = 0;
    Dwarf_Half address_size = 0;
    Dwarf_Unsigned next_cu_header = 0;
    Dwarf_Error dwarf_error;
    int cu_number = 0;
    
    for(;;++cu_number) {
        struct srcfilesdata sf;
        sf.srcfilesres = DW_DLV_ERROR;
        sf.srcfiles = 0;
        sf.srcfilescount = 0;
        Dwarf_Die no_die = 0;
        Dwarf_Die cu_die = 0;
        int res = DW_DLV_ERROR;
        res = dwarf_next_cu_header(dbg,&cu_header_length,
                                   &version_stamp, &abbrev_offset, &address_size,
                                   &next_cu_header, &dwarf_error);
        if (res == DW_DLV_ERROR) {
            NSString *reason = @"DWARF Error: Error in dwarf_next_cu_header";
            return FDErrorReturn(error, @{@"reason": reason});
        }
        if(res == DW_DLV_NO_ENTRY) {
            /* Done. */
            return YES;
        }
        /* The CU will have a single sibling, a cu_die. */
        res = dwarf_siblingof(dbg,no_die,&cu_die,&dwarf_error);
        if (res == DW_DLV_ERROR) {
            NSString *reason = @"DWARF Error: Error in dwarf_siblingof on CU die";
            return FDErrorReturn(error, @{@"reason": reason});
        }
        if (res == DW_DLV_NO_ENTRY) {
            /* Impossible case. */
            NSString *reason = @"DWARF Error: no entry! in dwarf_siblingof on CU die";
            return FDErrorReturn(error, @{@"reason": reason});
        }
        if (![self get_die_and_siblings:dbg in_die:cu_die in_level:0 sf:&sf error:error]) {
            return NO;
        }
        dwarf_dealloc(dbg,cu_die,DW_DLA_DIE);
        [self resetsrcfiles:dbg sf:&sf];
    }
    return YES;
}

- (BOOL)get_die_and_siblings:(Dwarf_Debug)dbg in_die:(Dwarf_Die)in_die in_level:(int)in_level sf:(struct srcfilesdata *)sf error:(NSError **)error
{
    int res = DW_DLV_ERROR;
    Dwarf_Die cur_die=in_die;
    Dwarf_Die child = 0;
    Dwarf_Error dwarf_error;
    
    if (![self print_die_data:dbg in_die:in_die in_level:in_level sf:sf error:error]) {
        return NO;
    }
    
    for(;;) {
        Dwarf_Die sib_die = 0;
        res = dwarf_child(cur_die,&child,&dwarf_error);
        if(res == DW_DLV_ERROR) {
            NSString *reason = [NSString stringWithFormat:@"Error in dwarf_child , level %d",in_level];
            return FDErrorReturn(error, @{@"reason": reason});
        }
        if(res == DW_DLV_OK) {
            if (![self get_die_and_siblings:dbg in_die:child in_level:in_level+1 sf:sf error:error]) {
                return NO;
            }
        }
        /* res == DW_DLV_NO_ENTRY */
        res = dwarf_siblingof(dbg,cur_die,&sib_die,&dwarf_error);
        if(res == DW_DLV_ERROR) {
            NSString *reason = [NSString stringWithFormat:@"Error in dwarf_siblingof , level %d",in_level];
            return FDErrorReturn(error, @{@"reason": reason});
        }
        if(res == DW_DLV_NO_ENTRY) {
            /* Done at this level. */
            break;
        }
        /* res == DW_DLV_OK */
        if(cur_die != in_die) {
            dwarf_dealloc(dbg,cur_die,DW_DLA_DIE);
        }
        cur_die = sib_die;
        if (![self print_die_data:dbg in_die:cur_die in_level:in_level sf:sf error:error]) {
            return NO;
        }
    }
    return YES;
}

- (void)get_addr:(Dwarf_Attribute)attr val:(Dwarf_Addr *)val
{
    Dwarf_Error error = 0;
    int res;
    Dwarf_Addr uval = 0;
    res = dwarf_formaddr(attr,&uval,&error);
    if(res == DW_DLV_OK) {
        *val = uval;
        return;
    }
    return;
}

- (void)get_number:(Dwarf_Attribute)attr val:(Dwarf_Unsigned *)val
{
    Dwarf_Error error = 0;
    int res;
    Dwarf_Signed sval = 0;
    Dwarf_Unsigned uval = 0;
    res = dwarf_formudata(attr,&uval,&error);
    if(res == DW_DLV_OK) {
        *val = uval;
        return;
    }
    res = dwarf_formsdata(attr,&sval,&error);
    if(res == DW_DLV_OK) {
        *val = sval;
        return;
    }
    return;
}

static const char *const dwarf_regnames_i386[] =
{
    "eax", "ecx", "edx", "ebx",
    "esp", "ebp", "esi", "edi",
    "eip", "eflags", NULL,
    "st0", "st1", "st2", "st3",
    "st4", "st5", "st6", "st7",
    NULL, NULL,
    "xmm0", "xmm1", "xmm2", "xmm3",
    "xmm4", "xmm5", "xmm6", "xmm7",
    "mm0", "mm1", "mm2", "mm3",
    "mm4", "mm5", "mm6", "mm7",
    "fcw", "fsw", "mxcsr",
    "es", "cs", "ss", "ds", "fs", "gs", NULL, NULL,
    "tr", "ldtr"  
};

static NSString *get_location(Dwarf_Debug dbg, Dwarf_Attribute attr, int level) {
    Dwarf_Error error = 0;
    int res;
    Dwarf_Locdesc *llbuf;
    Dwarf_Signed lcnt;
    NSString *loc = nil;
    res = dwarf_loclist(attr, &llbuf, &lcnt, &error);
    if (res == DW_DLV_OK) {
        if ( DW_OP_addr == llbuf->ld_s->lr_atom)
            loc = [NSString stringWithFormat:@"DW_OP_addr: %x \n",(int) llbuf->ld_s->lr_number];
        else if(llbuf->ld_s->lr_atom >= DW_OP_breg0 && llbuf->ld_s->lr_atom <= DW_OP_breg31)
            loc = [NSString stringWithFormat:@"DW_OP_bregn: %s %d \n",*(dwarf_regnames_i386+llbuf->ld_s->lr_atom-DW_OP_breg0),((int)llbuf->ld_s->lr_number)];
        else if(llbuf->ld_s->lr_atom >= DW_OP_reg0 && llbuf->ld_s->lr_atom <= DW_OP_reg31)
            loc = [NSString stringWithFormat:@"DW_OP_regn: reg%d \n",llbuf->ld_s->lr_atom - DW_OP_reg0];
        else if(llbuf->ld_s->lr_atom == DW_OP_fbreg)
            loc = [NSString stringWithFormat:@"DW_OP_fbreg: %s %d \n","sp",((int)llbuf->ld_s->lr_number)+8];
        else
            loc = @"Unknow location \n";
        dwarf_dealloc(dbg, llbuf->ld_s, DW_DLA_LOC_BLOCK);
        dwarf_dealloc(dbg, llbuf, DW_DLA_LOCDESC);
    }
    return loc;
}

static Dwarf_Die get_die(Dwarf_Debug dbg, Dwarf_Attribute attr, Dwarf_Half* tag) {
    Dwarf_Error error = 0;
    int res;
    Dwarf_Off offset;
    Dwarf_Die typeDie = 0;
    res = dwarf_global_formref(attr, &offset, &error);
    if (res == DW_DLV_OK) {
        res = dwarf_offdie(dbg, offset, &typeDie, &error);
        if (res == DW_DLV_OK) {
            res = dwarf_tag(typeDie, tag, &error);
            if (res == DW_DLV_OK) {
                return typeDie;
            }
        }
    }
    return NULL ;
}

static int get_array_length(Dwarf_Debug dbg, Dwarf_Die die, int *length) {
    int res;
    Dwarf_Error error;
    Dwarf_Die child;
    Dwarf_Attribute tmp;
    res = dwarf_child(die, &child, &error);
    *length = 1;
    Dwarf_Unsigned utmp;
    if (res == DW_DLV_OK) {
        while (1) {
            res = dwarf_attr(child, DW_AT_upper_bound, &tmp, &error);
            if (res == DW_DLV_OK) {
                res = dwarf_formudata(tmp, &utmp, &error);
                if (res != DW_DLV_OK)
                    return DW_DLV_ERROR;
                else
                    *length *= (utmp + 1);
            }
            res = dwarf_siblingof(dbg, child, &child, &error);
            if (res == DW_DLV_ERROR)
                return DW_DLV_ERROR;
            if (res == DW_DLV_NO_ENTRY)
                return DW_DLV_OK;
        }
    }
    return DW_DLV_ERROR;
}

- (void)get_type:(Dwarf_Debug)dbg attr:(Dwarf_Attribute)attr string:(NSMutableString *)type
{
    char *name = 0;
    Dwarf_Half tag;
    Dwarf_Unsigned size;
    Dwarf_Error error = 0;
    Dwarf_Attribute t_attr;
    int res;
    Dwarf_Die typeDie = get_die(dbg, attr, &tag);
    if (typeDie) {
        switch (tag) {
            case DW_TAG_subroutine_type:
                [type appendString:@"subroutine type return "];
                goto next_type;
            case DW_TAG_typedef:
                [type appendString:@"typedef to "];
                goto next_type;
            case DW_TAG_const_type:
                [type appendString:@"const "];
                goto next_type;
            case DW_TAG_pointer_type:
                [type appendString:@"pointer "];
                goto next_type;
            case DW_TAG_volatile_type:
                [type appendString:@"volatile "];
            next_type: res = dwarf_attr(typeDie, DW_AT_type, &t_attr, &error);
                if (res == DW_DLV_OK) {
                    [self get_type:dbg attr:t_attr string:type];
                } else
                    [type appendString:@"void \n"];
                break;
            case DW_TAG_base_type:
                res = dwarf_diename(typeDie, &name, &error);
                if (res == DW_DLV_OK) {
                    [type appendFormat:@"%s ", name];
                    res = dwarf_bytesize(typeDie, &size, &error);
                    if (res == DW_DLV_OK) {
                        [type appendFormat:@"\nbyte size %d \n", (int)size];
                    } else
                        [type appendString:@"error in get base type size \n"];
                } else
                    [type appendString:@"error in get base type name \n"];
                break;
            case DW_TAG_array_type:
                [type appendString:@"array "];
                int length;
                res = get_array_length(dbg, typeDie, &length);
                if (res == DW_DLV_OK)
                    [type appendFormat:@"length %d ", length];
                goto next_type;
            case DW_TAG_union_type:
                [type appendString:@"union "];
                goto get_size;
            case DW_TAG_structure_type:
                [type appendString:@"structure "];
            get_size: res = dwarf_bytesize(typeDie, &size, &error);
                if (res == DW_DLV_OK)
                    [type appendFormat:@"\nbyte size %d\n", (int)size];
                else
                    [type appendString:@"error in get bytesize\n"];
                break;  
            default:  
                [type appendString:@"Unknow tag \n"];  
                break;  
        }  
    }
}

- (BOOL)print_variable:(Dwarf_Debug)dbg die:(Dwarf_Die)die level:(int)level sf:(struct srcfilesdata *)sf error:(NSError **)error
{
    int res;
    Dwarf_Error dwarf_error = 0;
    Dwarf_Attribute *attrbuf = 0;
    Dwarf_Signed attrcount = 0;
    Dwarf_Unsigned i;
    
    Dwarf_Half tag = 0;
    res = dwarf_tag(die,&tag,&dwarf_error);
    if(res != DW_DLV_OK) {
        NSString *reason = [NSString stringWithFormat:@"DWARF Error: Error in dwarf_tag , level %d",level];
        return FDErrorReturn(error, @{@"reason": reason});
    }
    const char *tagname = 0;
    res = dwarf_get_TAG_name(tag,&tagname);
    if(res != DW_DLV_OK) {
        NSString *reason = [NSString stringWithFormat:@"DWARF Error: Error in dwarf_get_TAG_name , level %d",level];
        return FDErrorReturn(error, @{@"reason": reason});
    }
    if( tag == DW_TAG_formal_parameter) {
    }
    
    char *name = 0;
    res = dwarf_diename(die,&name,&dwarf_error);
    if(res == DW_DLV_ERROR) {
        NSString *reason = [NSString stringWithFormat:@"DWARF Error: Error in dwarf_diename , level %d",level];
        return FDErrorReturn(error, @{@"reason": reason});
    }

    res = dwarf_attrlist(die,&attrbuf,&attrcount,&dwarf_error);
    if(res != DW_DLV_OK) {
        NSString *reason = [NSString stringWithFormat:@"DWARF Error: Error in dwarf_attrlist , level %d",level];
        return FDErrorReturn(error, @{@"reason": reason});
    }
    NSMutableString *type = nil;
    NSString *location = nil;
    for(i = 0; i < attrcount ; ++i) {
        Dwarf_Half aform;
        res = dwarf_whatattr(attrbuf[i],&aform,&dwarf_error);
        if(res == DW_DLV_OK) {
            if(aform == DW_AT_declaration) {
            }
            if(aform == DW_AT_location) {
                location = get_location(dbg, attrbuf[i], level);
            }
            if(aform == DW_AT_type) {
                type = [NSMutableString string];
                [self get_type:dbg attr:attrbuf[i] string:type];
            }
        }
        dwarf_dealloc(dbg,attrbuf[i],DW_DLA_ATTR);
    }
    
    NSLog(@"%s %@ %@", name, type, location);
    return YES;
}

- (BOOL)print_args:(Dwarf_Debug)dbg in_die:(Dwarf_Die)in_die in_level:(int)in_level sf:(struct srcfilesdata *)sf error:(NSError **)error
{
    int res;
    Dwarf_Error dwarf_error = 0;
    Dwarf_Die cur_die=in_die;
    Dwarf_Die child = 0;
    for(;;) {
        Dwarf_Die sib_die = 0;
        res = dwarf_child(cur_die,&child,&dwarf_error);
        if(res == DW_DLV_ERROR) {
            NSString *reason = [NSString stringWithFormat:@"DWARF Error: Error in dwarf_child , level %d",in_level];
            return FDErrorReturn(error, @{@"reason": reason});
        }
        if(res == DW_DLV_OK) {
            if (![self print_variable:dbg die:child level:in_level+1 sf:sf error:error]) {
                return NO;
            }
        }
        /* res == DW_DLV_NO_ENTRY */
        res = dwarf_siblingof(dbg,cur_die,&sib_die,&dwarf_error);
        if(res == DW_DLV_ERROR) {
            NSString *reason = [NSString stringWithFormat:@"DWARF Error: Error in dwarf_siblingof , level %d",in_level];
            return FDErrorReturn(error, @{@"reason": reason});
        }
        if(res == DW_DLV_NO_ENTRY) {
            /* Done at this level. */
            break;
        }
        
        char* name = 0;
        res = dwarf_diename(cur_die,&name,&dwarf_error);
        if(res == DW_DLV_ERROR) {
            NSString *reason = [NSString stringWithFormat:@"DWARF Error: Error in dwarf_diename , level %d",in_level];
            return FDErrorReturn(error, @{@"reason": reason});
        }
        if(res == DW_DLV_NO_ENTRY) {
        }
        /* res == DW_DLV_OK */
        if(cur_die != in_die) {
            dwarf_dealloc(dbg,cur_die,DW_DLA_DIE);
        }
        cur_die = sib_die;
    }
    return YES;
}

- (void)print_subprog:(Dwarf_Debug)dbg name:(char *)name die:(Dwarf_Die)die level:(int)level sf:(struct srcfilesdata *)sf
{
    int res;
    Dwarf_Error error = 0;
    Dwarf_Attribute *attrbuf = 0;
    Dwarf_Addr lowpc = 0;
    Dwarf_Addr highpc = 0;
    NSMutableString *type = 0;
    Dwarf_Signed attrcount = 0;
    Dwarf_Unsigned i;
    Dwarf_Unsigned filenum = 0;
    Dwarf_Unsigned linenum = 0;
    char *filename = 0;
    res = dwarf_attrlist(die,&attrbuf,&attrcount,&error);
    if(res != DW_DLV_OK) {
        return;
    }
    for(i = 0; i < attrcount ; ++i) {
        Dwarf_Half aform;
        res = dwarf_whatattr(attrbuf[i],&aform,&error);
        if(res == DW_DLV_OK) {
            if(aform == DW_AT_decl_file) {
                [self get_number:attrbuf[i] val:&filenum];
                if((filenum > 0) && (sf->srcfilescount > (filenum-1))) {
                    filename = sf->srcfiles[filenum-1];
                }
            }
            if(aform == DW_AT_decl_line) {
                [self get_number:attrbuf[i] val:&linenum];
            }
            if(aform == DW_AT_low_pc) {
                [self get_addr:attrbuf[i] val:&lowpc];
            }
            if(aform == DW_AT_high_pc) {
                [self get_addr:attrbuf[i] val:&highpc];
            }
            if(aform == DW_AT_type) {
                type = [NSMutableString string];
                [self get_type:dbg attr:attrbuf[i] string:type];
            }
        }
        dwarf_dealloc(dbg,attrbuf[i],DW_DLA_ATTR);
    }

//    NSLog(@"function: %s address: %08llx file: %s line: %lld", name, lowpc, filename ? filename : "", linenum);
    
    FDExecutableFunction *function = [[FDExecutableFunction alloc] init];
    function.name = [NSString stringWithCString:name encoding:NSASCIIStringEncoding];
    function.address = (uint32_t)lowpc;
    [_functions setObject:function forKey:function.name];
    
//    NSLog(@"function %@ %@", function.name, type);
//    [self print_args:dbg in_die:die in_level:level sf:sf];
    
    dwarf_dealloc(dbg,attrbuf,DW_DLA_LIST);
}

- (void)print_comp_dir:(Dwarf_Debug)dbg die:(Dwarf_Die)die level:(int)level sf:(struct srcfilesdata *)sf
{
    int res;
    Dwarf_Error error = 0;
    Dwarf_Attribute *attrbuf = 0;
    Dwarf_Signed attrcount = 0;
    Dwarf_Unsigned i;
    res = dwarf_attrlist(die,&attrbuf,&attrcount,&error);
    if(res != DW_DLV_OK) {
        return;
    }
    sf->srcfilesres = dwarf_srcfiles(die,&sf->srcfiles,&sf->srcfilescount,
                                     &error);
    for(i = 0; i < attrcount ; ++i) {
        Dwarf_Half aform;
        res = dwarf_whatattr(attrbuf[i],&aform,&error);
        if(res == DW_DLV_OK) {
            if(aform == DW_AT_comp_dir) {
                char *name = 0;
                res = dwarf_formstring(attrbuf[i],&name,&error);
                if(res == DW_DLV_OK) {
//                    NSLog(@"<%3d> compilation directory : \"%s\"", level,name);
                }
            }
            if(aform == DW_AT_stmt_list) {
                /* Offset of stmt list for this CU in .debug_line */
            }
        }
        dwarf_dealloc(dbg,attrbuf[i],DW_DLA_ATTR);
    }
    dwarf_dealloc(dbg,attrbuf,DW_DLA_LIST);
}

- (void)resetsrcfiles:(Dwarf_Debug)dbg sf:(struct srcfilesdata *)sf
{
    Dwarf_Signed sri = 0;
    for (sri = 0; sri < sf->srcfilescount; ++sri) {
        dwarf_dealloc(dbg, sf->srcfiles[sri], DW_DLA_STRING);
    }
    dwarf_dealloc(dbg, sf->srcfiles, DW_DLA_LIST);
    sf->srcfilesres = DW_DLV_ERROR;
    sf->srcfiles = 0;
    sf->srcfilescount = 0;
}

- (BOOL)print_die_data:(Dwarf_Debug)dbg in_die:(Dwarf_Die)print_me in_level:(int)level sf:(struct srcfilesdata *)sf error:(NSError **)error
{
    char *name = 0;
    Dwarf_Error dwarf_error = 0;
    Dwarf_Half tag = 0;
    const char *tagname = 0;
    int localname = 0;
    
    int res = dwarf_diename(print_me,&name,&dwarf_error);
    
    if(res == DW_DLV_ERROR) {
        NSString *reason = [NSString stringWithFormat:@"Error in dwarf_diename , level %d",level];
        return FDErrorReturn(error, @{@"reason": reason});
    }
    if(res == DW_DLV_NO_ENTRY) {
        name = "<no DW_AT_name attr>";
        localname = 1;
    }
    res = dwarf_tag(print_me,&tag,&dwarf_error);
    if(res != DW_DLV_OK) {
        NSString *reason = [NSString stringWithFormat:@"Error in dwarf_tag , level %d",level];
        return FDErrorReturn(error, @{@"reason": reason});
    }
    res = dwarf_get_TAG_name(tag,&tagname);
    if(res != DW_DLV_OK) {
        NSString *reason = [NSString stringWithFormat:@"Error in dwarf_get_TAG_name , level %d",level];
        return FDErrorReturn(error, @{@"reason": reason});
    }
    bool namesoptionon = true;
    if(namesoptionon) {
        if( tag == DW_TAG_subprogram) {
//            NSLog(@"<%3d> subprogram            : \"%s\"",level,name);
            [self print_subprog:dbg name:name die:print_me level:level sf:sf];
        } else if (tag == DW_TAG_compile_unit || tag == DW_TAG_partial_unit || tag == DW_TAG_type_unit) {
            [self resetsrcfiles:dbg sf:sf];
//            NSLog(@"<%3d> source file           : \"%s\"",level,name);
            [self print_comp_dir:dbg die:print_me level:level sf:sf];
        }
    }
    if(!localname) {
        dwarf_dealloc(dbg,name,DW_DLA_STRING);
    }
    return YES;
}

- (BOOL)loadSymbols:(const char *)filename error:(NSError **)error
{
    int fd;
    if ((fd = open(filename, O_RDONLY, 0)) < 0) {
        NSString *reason = [NSString stringWithFormat:@"open \"%s\" failed", filename];
        return FDErrorReturn(error, @{@"reason": reason});
    }
    Dwarf_Handler errhand = 0;
    Dwarf_Ptr errarg = 0;
    Dwarf_Debug dbg = 0;
    Dwarf_Error dwarf_error;
    int res = dwarf_init(fd, DW_DLC_READ, errhand, errarg, &dbg, &dwarf_error);
    if (res != DW_DLV_OK) {
        NSString *reason = @"DWARF Error: Giving up, cannot do DWARF processing";
        return FDErrorReturn(error, @{@"reason": reason});
    }
    
    BOOL result = [self read_cu_list:dbg error:error];
    dwarf_finish(dbg, &dwarf_error);
    close(fd);
    return result;
}

- (void)readSymtab:(Elf *)elf scn:(Elf_Scn *)scn shdr:(GElf_Shdr *)shdr
{
    // edata points to our symbol table
    Elf_Data *edata = NULL;
    edata = elf_getdata(scn, edata);
    
    // how many symbols are there? this number comes from the size of
    // the section divided by the entry size
    unsigned long symbol_count = shdr->sh_size / shdr->sh_entsize;
    
    // loop through to grab all symbols
    for(int i = 0; i < symbol_count; i++)
    {
        // libelf grabs the symbol data using gelf_getsym()
        GElf_Sym sym;
        gelf_getsym(edata, i, &sym);
        
        // type of symbol binding
        if (ELF32_ST_BIND(sym.st_info) != STB_GLOBAL) {
            continue;
        }

        // type of symbol
        if (ELF32_ST_TYPE(sym.st_info) != STT_NOTYPE) {
            continue;
        }
        
        char* cname = elf_strptr(elf, shdr->sh_link, sym.st_name);
        NSString *name = [NSString stringWithCString:cname encoding:NSASCIIStringEncoding];
        FDExecutableSymbol *symbol = [[FDExecutableSymbol alloc] init];
        symbol.name = name;
        symbol.address = (uint32_t)sym.st_value;
        _globals[name] = symbol;
    }
}

- (BOOL)loadProgram:(const char *)filename error:(NSError **)error
{
    if (elf_version(EV_CURRENT) == EV_NONE) {
        NSString *reason = [NSString stringWithFormat:@"ELF Error: ELF library initialization failed: %s", elf_errmsg(-1)];
        return FDErrorReturn(error, @{@"reason": reason});
    }
    int fd;
    if ((fd = open(filename, O_RDONLY, 0)) < 0) {
        NSString *reason = [NSString stringWithFormat:@"ELF Error: open \"%s\" failed", filename];
        return FDErrorReturn(error, @{@"reason": reason});
    }
    Elf *e;
    if ((e = elf_begin(fd, ELF_C_READ , NULL)) == NULL) {
        NSString *reason = [NSString stringWithFormat:@"ELF Error: elf_begin() failed: %s.", elf_errmsg(-1)];
        return FDErrorReturn(error, @{@"reason": reason});
    }
    
    Elf_Kind kind = elf_kind(e);
    if (kind != ELF_K_ELF) {
        NSString *reason = @"ELF Error: elf_kind != ELF_K_ELF";
        return FDErrorReturn(error, @{@"reason": reason});
    }
    
    
    NSMutableDictionary *sectionByAddress = [NSMutableDictionary dictionary];
    size_t shstrndx;
    if (elf_getshdrstrndx(e, &shstrndx) != 0) {
        NSString *reason = [NSString stringWithFormat:@"ELF Error: getshstrndx() failed: %s.", elf_errmsg(-1)];
        return FDErrorReturn(error, @{@"reason": reason});
    }
    Elf_Scn *scn = NULL;
    while ((scn = elf_nextscn(e, scn)) != NULL) {
        GElf_Shdr shdr;
        if (gelf_getshdr(scn, &shdr) != &shdr) {
            NSString *reason = [NSString stringWithFormat:@"ELF Error: getshdr() failed: %s.", elf_errmsg(-1)];
            return FDErrorReturn(error, @{@"reason": reason});
        }
        if (shdr.sh_type == SHT_SYMTAB) {
            [self readSymtab:e scn:scn shdr:&shdr];
        }
        if (shdr.sh_type != SHT_PROGBITS) {
            continue;
        }
        if ((shdr.sh_flags & SHF_ALLOC) == 0) {
            continue;
        }
        
        uint32_t address = (uint32_t)shdr.sh_addr;
        
        char *name;
        if ((name = elf_strptr(e, shstrndx, shdr.sh_name)) == NULL) {
            NSString *reason = [NSString stringWithFormat:@"ELF Error: elf_strptr() failed: %s.", elf_errmsg(-1)];
            return FDErrorReturn(error, @{@"reason": reason});
        }
        
        NSMutableData *sectionData = [NSMutableData data];
        Elf_Data *data = NULL;
        size_t n = 0;
        while (n < shdr.sh_size && (data = elf_getdata(scn, data)) != NULL) {
            [sectionData appendBytes:(uint8_t *)data->d_buf length:data->d_size];
            n += data->d_size;
        }

//        NSLog(@"Section %-4.4jd %s %08x %ld", (uintmax_t) elf_ndxscn(scn), name, address, sectionData.length);
        
        FDExecutableSection *section = [[FDExecutableSection alloc] init];
        section.type = FDExecutableSectionTypeProgram;
        section.address = address;
        section.data = sectionData;
        NSNumber *key = [NSNumber numberWithLong:address];
        [sectionByAddress setObject:section forKey:key];
    }
    
    
    
    GElf_Ehdr ehdr;
    if (gelf_getehdr(e, &ehdr) == NULL) {
        NSString *reason = [NSString stringWithFormat:@"ELF Error: getehdr() failed: %s.", elf_errmsg(-1)];
        return FDErrorReturn(error, @{@"reason": reason});
    }
    
    size_t n;
    if (elf_getphdrnum(e, &n) != 0) {
        NSString *reason = [NSString stringWithFormat:@"ELF Error: elf_getphnum() failed: %s.", elf_errmsg(-1)];
        return FDErrorReturn(error, @{@"reason": reason});
    }
    for (int i = 0; i < n; i++) {
        GElf_Phdr phdr;
        if (gelf_getphdr(e, i, &phdr) != &phdr) {
            NSString *reason = [NSString stringWithFormat:@"ELF Error: getphdr() failed: %s.", elf_errmsg(-1)];
            return FDErrorReturn(error, @{@"reason": reason});
        }
        if (phdr.p_type != PT_LOAD) {
            continue;
        }
        if (phdr.p_vaddr == phdr.p_paddr) {
            continue;
        }

        /*
        lseek(fd, phdr.p_offset, SEEK_SET);
        uint8_t *bytes = malloc(phdr.p_filesz);
        size_t n = read(fd, bytes, phdr.p_filesz);
        NSMutableData *data = [NSMutableData dataWithBytes:bytes length:phdr.p_filesz];
        free(bytes);
        if (n != phdr.p_filesz) {
            NSString *reason = @"ELF Error: read failed";
            return FDErrorReturn(error, @{@"reason", reason});
        }
        [data setLength:phdr.p_memsz];
        */
        
        // remap virtual address to physical address for loading into flash -denis
//        NSLog(@"program p_vaddr=0x%08lx p_paddr=0x%08lx", phdr.p_vaddr, phdr.p_paddr);
        NSNumber *key = [NSNumber numberWithLong:phdr.p_vaddr];
        FDExecutableSection *section = [sectionByAddress objectForKey:key];
        if (section) {
            [sectionByAddress removeObjectForKey:key];
            section.address = (uint32_t)phdr.p_paddr;
            key = [NSNumber numberWithLong:section.address];
            [sectionByAddress setObject:section forKey:key];
        }
    }
    
    elf_end(e);
    close(fd);
    
    _sections = [sectionByAddress allValues];

    return YES;
}

- (BOOL)load:(NSString *)filename error:(NSError **)error
{
    const char* cfilename = [filename cStringUsingEncoding:NSASCIIStringEncoding];
    if (![self loadSymbols:cfilename error:error]) {
        return NO;
    }
    if (![self loadProgram:cfilename error:error]) {
        return NO;
    }
    return YES;
}

- (NSArray *)combineSectionsType:(FDExecutableSectionType)type
                         address:(uint32_t)address
                          length:(uint32_t)length
                        pageSize:(uint32_t)pageSize
{
    uint32_t end = address + length;
    uint32_t min = 0xffffffff;
    uint32_t max = 0x00000000;
    NSMutableArray *sections = [NSMutableArray array];
    NSMutableArray *candidates = [NSMutableArray array];
    for (FDExecutableSection *section in _sections) {
        uint32_t sectionEnd = section.address + (uint32_t)section.data.length;
        if ((section.type != type) || (section.address < address) || (sectionEnd > end)) {
            [sections addObject:section];
            continue;
        }
        if (section.address < min) {
            min = section.address;
        }
        if (sectionEnd > max) {
            max = sectionEnd;
        }
        [candidates addObject:section];
    }
    if (candidates.count > 0) {
        min = min & ~(pageSize - 1); // round down to page boundary
        max = (max + (pageSize - 1)) & ~(pageSize - 1); // round up to page boundary
        uint32_t combinedLength = max - min;
        NSMutableData *data = [NSMutableData data];
        data.length = combinedLength;
        for (FDExecutableSection *section in candidates) {
            uint32_t location = section.address - min;
            [data replaceBytesInRange:NSMakeRange(location, section.data.length) withBytes:section.data.bytes];
        }
        FDExecutableSection *section = [[FDExecutableSection alloc] init];
        section.type = type;
        section.address = min;
        section.data = data;
        [sections addObject:section];
    }
    return sections;
}

- (NSArray *)combineAllSectionsType:(FDExecutableSectionType)type
                            address:(uint32_t)address
                             length:(uint32_t)length
                           pageSize:(uint32_t)pageSize
{
    uint32_t end = address + length;
    uint32_t min = 0xffffffff;
    uint32_t max = 0x00000000;
    NSMutableArray *sections = [NSMutableArray array];
    NSMutableArray *candidates = [NSMutableArray array];
    for (FDExecutableSection *section in _sections) {
        uint32_t sectionEnd = section.address + (uint32_t)section.data.length;
        if ((section.address < address) || (sectionEnd > end)) {
            [sections addObject:section];
            continue;
        }
        if (section.address < min) {
            min = section.address;
        }
        if (sectionEnd > max) {
            max = sectionEnd;
        }
        [candidates addObject:section];
    }
    if (candidates.count > 0) {
        min = min & ~(pageSize - 1); // round down to page boundary
        max = (max + (pageSize - 1)) & ~(pageSize - 1); // round up to page boundary
        uint32_t combinedLength = max - min;
        NSMutableData *data = [NSMutableData data];
        data.length = combinedLength;
        for (FDExecutableSection *section in candidates) {
            uint32_t location = section.address - min;
            [data replaceBytesInRange:NSMakeRange(location, section.data.length) withBytes:section.data.bytes];
        }
        FDExecutableSection *section = [[FDExecutableSection alloc] init];
        section.type = type;
        section.address = min;
        section.data = data;
        [sections addObject:section];
    }
    return sections;
}

@end
