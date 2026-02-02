#ifndef VALUE_H
#define VALUE_H

enum class Valuetype {
    STRING
};

struct Value {
    Valuetype type;
    void* data;
};

#endif // VALUE_H