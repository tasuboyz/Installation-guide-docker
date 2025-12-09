FROM ubuntu:24.04

# Installazione delle dipendenze
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y make git zlib1g-dev libssl-dev gperf cmake clang-18 libc++-18-dev libc++abi-18-dev

# Clona il repository telegram-bot-api
RUN git clone --recursive https://github.com/tdlib/telegram-bot-api.git /telegram-bot-api

WORKDIR /telegram-bot-api

# Compila il progetto
RUN rm -rf build && \
    mkdir build && \
    cd build && \
    CXXFLAGS="-stdlib=libc++" CC=/usr/bin/clang-18 CXX=/usr/bin/clang++-18 cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX:PATH=.. .. && \
    cmake --build . --target install

# Espone la porta 8081 (default telegram-bot-api)
EXPOSE 8081

# Comando di avvio
CMD ["./bin/telegram-bot-api", "--help"]
