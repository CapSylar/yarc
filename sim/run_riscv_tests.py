import os
import shutil
import sys, getopt, glob, re
import subprocess
import filecmp
from termcolor import colored

success_token = "TEST OK"

def run_tests(argv):
    dir = ""
    isas = []
    dump = False

    try:
        opts, _ = getopt.getopt(argv, "", ["dir=","isa=","dump"])
    except getopt.GetoptError:
        print("Usage: run_riscv_tests.py --dir=<directory> --isa=<isa0> --isa=<isa1> [--dump]")
        sys.exit(2)

    for flag, arg in opts:
        if flag in ("--dir"):
            dir = arg
        elif flag in ("--isa"):
            isas.append(arg)
        elif flag in ("--dump"):
            dump = True

    print(f"running with the following configs: dir={dir}, isa={isas}")

    testfiles = []
    # find all ELF files for the given ISA

    for isa in isas:
        for file in glob.glob(f"{dir}/{isa}-p-*"):
            if re.search(".*dump.*", file) is None: # does no contain dump in the filename
                testfiles.append(file)
    
    print(f"found {len(testfiles)} testfiles")
    
    os.makedirs("temp", exist_ok=True)

    failed_tests = 0

    # make questa compile the source once
    for testfile in testfiles:
        # transform the test into a vmem file
        subprocess.run([f"./gen_vmem.sh {testfile} ./temp"], shell=True)

        filename =os.path.basename(testfile) 
        vmem_file = f"./temp/{filename}.vmem"
        signature_file = f"./temp/{filename}_testsig.txt"

        # first run questa over the testfile

        # extract end_signature location from elf file
        completed = subprocess.run([f"readelf -s {testfile} | grep end_signature | awk '{{print $2}}'"], capture_output=True, shell=True,)
        end_signature = completed.stdout.decode().strip()
        # extract begin_signature from elf file
        completed = subprocess.run([f"readelf -s {testfile} | grep begin_signature | awk '{{print $2}}'"], capture_output=True, shell=True)
        begin_signature = completed.stdout.decode().strip()

        run_command = f"make questa MODE=compliance MEMFILE={vmem_file} begin_signature={begin_signature} end_signature={end_signature} sig_filename_o={signature_file} IS_GUI=0"
        
        if dump:
            print(f"run command: {colored(run_command,'yellow')}")

        completed = subprocess.run([run_command], shell=True, capture_output=True)
        run_log = completed.stdout.decode()

        # output a log file to temp
        with open(f"./temp/{filename}_run.vsimlog", "w") as vsimlog:
            vsimlog.write(run_log)

        test_success = run_log.find(success_token) > 0 # True if success_token is found
        sig_message = colored("Not Present", "yellow")
        sig_match = True

        if end_signature > begin_signature: # a memory signature is present
            # run spike to generate the memory signature file
            spikesig_file = f"./temp/{filename}_spikesig.txt"
            spike_log = f"./temp/{filename}_spike.log"

            spike_run_command = f"spike --isa=RV32I -l --log={spike_log} +signature={spikesig_file} --signature={spikesig_file} {testfile}"
            
            if dump:
                print(f"spike run command {colored(spike_run_command,'yellow')}")

            subprocess.run([spike_run_command], capture_output=True, shell=True)

            sig_match = filecmp.cmp(spikesig_file, signature_file)
            sig_message = get_colored_str(sig_match)

        if (not test_success or not sig_match):
            failed_tests += 1

        print(f"test with {filename} run success:{get_colored_str(test_success)}, memory signatures match: {sig_message}")
    
    print(f"successful_tests: {len(testfiles)-failed_tests} || failed_tests: {failed_tests}")

def get_colored_str(status: bool):
    return colored("True", "green") if status else colored("False", "red")

if __name__ == "__main__":
    # make sure prerequisites like spike and objcopy riscv are present
    prerequisites = ["spike", "riscv-none-elf-objcopy", "readelf"]
    for pre in prerequisites:
        if not shutil.which(pre):
            print(colored(f"Error: {pre} not found in PATH. Please install it before running the tests.", "red"))
            sys.exit(1) 
    run_tests(sys.argv[1:])
