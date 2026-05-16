#include <algorithm>
#include <cctype>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <string>
#include <unordered_map>
#include <vector>

using namespace std;

class Instruction {
private:
    string name;
    vector<string> arguments;
    string interpretation;
    int length;

public:
    Instruction() : name(""), interpretation(""), length(0) {}

    Instruction(string n, vector<string> args, string interp)
        : name(std::move(n)),
          arguments(std::move(args)),
          interpretation(std::move(interp)),
          length(static_cast<int>(arguments.size())) {}

    const string& getName() const { return name; }
    const vector<string>& getArguments() const { return arguments; }
    const string& getInterpretation() const { return interpretation; }
    int getLength() const { return length; }

    string toString() const {
        ostringstream oss;
        oss << name;
        for (const auto& arg : arguments) {
            oss << " " << arg;
        }
        return oss.str();
    }
};

class Lexer {
public:
    static string toLowerCopy(string s) {
        transform(s.begin(), s.end(), s.begin(), [](unsigned char c) {
            return static_cast<char>(tolower(c));
        });
        return s;
    }

    static bool isDigits(const string& token) {
        if (token.empty()) return false;
        return all_of(token.begin(), token.end(), [](unsigned char c) {
            return isdigit(c);
        });
    }

    static bool isIdentifier(const string& token) {
        if (token.empty()) return false;
        if (!(isalpha(static_cast<unsigned char>(token[0])) || token[0] == '_')) {
            return false;
        }
        return all_of(token.begin() + 1, token.end(), [](unsigned char c) {
            return isalnum(c) || c == '_';
        });
    }

    static bool isKeyword(const string& token) {
        static const unordered_map<string, bool> keywords = {
            {"start", true}, {"stop", true}, {"move", true}, {"add", true},
            {"sub", true},   {"mult", true},  {"div", true},  {"sto", true}
        };
        return keywords.find(toLowerCopy(token)) != keywords.end();
    }

    static vector<string> tokenize(const string& line) {
        string normalized = line;
        for (char& c : normalized) {
            if (c == ',' || c == ';' || c == '\t') {
                c = ' ';
            }
        }

        istringstream iss(normalized);
        vector<string> tokens;
        string token;
        while (iss >> token) {
            tokens.push_back(token);
        }
        return tokens;
    }
};

class ProgramParser {
public:
    static Instruction parseLine(const string& line) {
        auto tokens = Lexer::tokenize(line);
        if (tokens.empty()) {
            return Instruction();
        }

        string op = Lexer::toLowerCopy(tokens[0]);

        if (!Lexer::isKeyword(op)) {
            throw runtime_error("Token invalido: " + tokens[0]);
        }

        vector<string> args;
        for (size_t i = 1; i < tokens.size(); ++i) {
            args.push_back(tokens[i]);
        }

        if (op == "start" || op == "stop") {
            if (!args.empty()) {
                throw runtime_error("La instruccion '" + op + "' no acepta argumentos.");
            }
            return Instruction(op, args, (op == "start")
                                          ? "Inicio del programa"
                                          : "Fin del programa");
        }

        if (op == "move") {
            if (args.size() != 2) {
                throw runtime_error("La instruccion 'move' requiere 2 argumentos.");
            }
            if (!Lexer::isIdentifier(args[0])) {
                throw runtime_error("Destino invalido en 'move': " + args[0]);
            }
            if (!Lexer::isDigits(args[1])) {
                throw runtime_error("Direccion invalida en 'move': " + args[1]);
            }
            return Instruction(op, args, "Mover un valor desde memoria a un registro");
        }

        if (op == "add" || op == "sub" || op == "mult" || op == "div") {
            if (args.size() != 2) {
                throw runtime_error("La instruccion '" + op + "' requiere 2 argumentos.");
            }
            if (!Lexer::isIdentifier(args[0]) || !Lexer::isIdentifier(args[1])) {
                throw runtime_error("Los argumentos de '" + op + "' deben ser identificadores de registros.");
            }

            if (op == "add")  return Instruction(op, args, "Sumar los contenidos de dos registros");
            if (op == "sub")  return Instruction(op, args, "Restar los contenidos de dos registros");
            if (op == "mult") return Instruction(op, args, "Multiplicar los contenidos de dos registros");
            return Instruction(op, args, "Dividir los contenidos de dos registros");
        }

        if (op == "sto") {
            if (args.size() != 1) {
                throw runtime_error("La instruccion 'sto' requiere 1 argumento.");
            }
            if (!Lexer::isDigits(args[0])) {
                throw runtime_error("La direccion de 'sto' debe ser numerica.");
            }
            return Instruction(op, args, "Almacenar el contenido del acumulador en memoria");
        }

        throw runtime_error("Instruccion no soportada: " + op);
    }
};

class Memory {
private:
    vector<Instruction> program;
    unordered_map<int, int> data;

public:
    void loadProgram(const vector<Instruction>& instructions) {
        program = instructions;
    }

    const Instruction& fetchInstruction(size_t pc) const {
        if (pc >= program.size()) {
            throw runtime_error("PC fuera de rango.");
        }
        return program[pc];
    }

    bool hasNext(size_t pc) const {
        return pc < program.size();
    }

    void writeData(int address, int value) {
        data[address] = value;
    }

    int readData(int address) const {
        auto it = data.find(address);
        if (it == data.end()) {
            throw runtime_error("No existe dato en la direccion de memoria " + to_string(address));
        }
        return it->second;
    }

    bool existsData(int address) const {
        return data.find(address) != data.end();
    }

    void preloadData(int address, int value) {
        data[address] = value;
    }

    void printDataAt(int address) const {
        cout << "MEM[" << address << "] = ";
        if (existsData(address)) {
            cout << readData(address);
        } else {
            cout << "undefined";
        }
        cout << '\n';
    }
};

struct Registers {
    int PC = 0;
    string IR = "";
    int ACC = 0;
    int MAR = 0;
    int MBR = 0;
    int AL = 0;
    int AH = 0;
    int BL = 0;
    int BH = 0;
    bool halted = false;
};

class ALU {
public:
    static int add(int a, int b) { return a + b; }
    static int sub(int a, int b) { return a - b; }
    static int mult(int a, int b) { return a * b; }

    static int divi(int a, int b) {
        if (b == 0) {
            throw runtime_error("Division entre cero.");
        }
        return a / b;
    }
};

class ControlUnit {
private:
    static bool isWritableRegister(const string& reg) {
        string r = Lexer::toLowerCopy(reg);
        return r == "al" || r == "ah" || r == "bl" || r == "bh" || r == "acc";
    }

    static int& getRegisterReference(const string& reg, Registers& R) {
        string r = Lexer::toLowerCopy(reg);
        if (r == "al")  return R.AL;
        if (r == "ah")  return R.AH;
        if (r == "bl")  return R.BL;
        if (r == "bh")  return R.BH;
        if (r == "acc") return R.ACC;

        throw runtime_error("Registro no soportado como destino: " + reg);
    }

    static int getRegisterValue(const string& reg, const Registers& R) {
        string r = Lexer::toLowerCopy(reg);
        if (r == "al")  return R.AL;
        if (r == "ah")  return R.AH;
        if (r == "bl")  return R.BL;
        if (r == "bh")  return R.BH;
        if (r == "acc") return R.ACC;
        throw runtime_error("Registro no soportado como fuente: " + reg);
    }

public:
    static void decode(const Instruction& instr) {
        cout << "Interpretacion: " << instr.getInterpretation() << '\n';
        cout << "Longitud: " << instr.getLength() << '\n';
    }

    static void execute(const Instruction& instr, Memory& memory, Registers& R) {
        string op = Lexer::toLowerCopy(instr.getName());
        const auto& args = instr.getArguments();

        if (op == "start") {
            return;
        }

        if (op == "stop") {
            R.halted = true;
            return;
        }

        if (op == "move") {
            const string& reg = args[0];
            int address = stoi(args[1]);

            if (!isWritableRegister(reg)) {
                throw runtime_error("No se puede cargar en el registro: " + reg);
            }

            R.MAR = address;
            R.MBR = memory.readData(address);
            getRegisterReference(reg, R) = R.MBR;
            return;
        }

        if (op == "add" || op == "sub" || op == "mult" || op == "div") {
            int a = getRegisterValue(args[0], R);
            int b = getRegisterValue(args[1], R);

            if (op == "add")  R.ACC = ALU::add(a, b);
            if (op == "sub")  R.ACC = ALU::sub(a, b);
            if (op == "mult") R.ACC = ALU::mult(a, b);
            if (op == "div")  R.ACC = ALU::divi(a, b);
            return;
        }

        if (op == "sto") {
            int address = stoi(args[0]);
            R.MAR = address;
            R.MBR = R.ACC;
            memory.writeData(address, R.ACC);
            return;
        }

        throw runtime_error("Operacion no reconocida en execute: " + op);
    }
};

class VirtualMachine {
private:
    Memory memory;
    Registers regs;

    void printRegisters(const string& stage) const {
        cout << "\n========== " << stage << " ==========\n";
        cout << left << setw(6) << "PC"  << ": " << regs.PC  << '\n';
        cout << left << setw(6) << "IR"  << ": " << regs.IR  << '\n';
        cout << left << setw(6) << "ACC" << ": " << regs.ACC << '\n';
        cout << left << setw(6) << "MAR" << ": " << regs.MAR << '\n';
        cout << left << setw(6) << "MBR" << ": " << regs.MBR << '\n';
        cout << left << setw(6) << "AL"  << ": " << regs.AL  << '\n';
        cout << left << setw(6) << "AH"  << ": " << regs.AH  << '\n';
        cout << left << setw(6) << "BL"  << ": " << regs.BL  << '\n';
        cout << left << setw(6) << "BH"  << ": " << regs.BH  << '\n';
    }

    void printCycleHeader(size_t cycle) const {
        cout << "\n========================================\n";
        cout << "CICLO MAQUINA #" << cycle << '\n';
        cout << "========================================\n";
    }

public:
    void preloadMemory(int address, int value) {
        memory.preloadData(address, value);
    }

    void loadProgramFromText(const vector<string>& lines) {
        vector<Instruction> program;
        for (const auto& line : lines) {
            Instruction instr = ProgramParser::parseLine(line);
            if (!instr.getName().empty()) {
                program.push_back(instr);
            }
        }
        memory.loadProgram(program);
    }

    void run() {
        size_t cycle = 0;

        while (memory.hasNext(static_cast<size_t>(regs.PC)) && !regs.halted) {
            printCycleHeader(cycle);

            const Instruction& instr = memory.fetchInstruction(static_cast<size_t>(regs.PC));
            regs.MAR = regs.PC;
            regs.IR = instr.toString();
            regs.PC++;

            cout << "[FETCH]\n";
            printRegisters("Estado despues de FETCH");

            cout << "\n[DECODE]\n";
            ControlUnit::decode(instr);
            printRegisters("Estado durante DECODE");

            cout << "\n[EXECUTE]\n";
            ControlUnit::execute(instr, memory, regs);
            printRegisters("Estado despues de EXECUTE");

            cycle++;
        }

        cout << "\n========================================\n";
        cout << "PROGRAMA FINALIZADO\n";
        cout << "========================================\n";
        cout << "Resultado aritmetico en ACC = " << regs.ACC << '\n';
    }

    const Registers& getRegisters() const {
        return regs;
    }

    void showMemoryValue(int address) const {
        memory.printDataAt(address);
    }
};

int main() {
    try {
        VirtualMachine vm;

        // Carga de datos en memoria principal
        vm.preloadMemory(10, 7);
        vm.preloadMemory(11, 5);

        // Programa de ejemplo
        vector<string> program = {
            "start",
            "move AL 10",
            "move BL 11",
            "add AL BL",
            "sto 20",
            "stop"
        };

        vm.loadProgramFromText(program);
        vm.run();

        cout << "\nEstado final en memoria:\n";
        vm.showMemoryValue(20);

        return 0;
    }
    catch (const exception& ex) {
        cerr << "\nERROR: " << ex.what() << '\n';
        return 1;
    }
}