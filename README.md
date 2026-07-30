# c3-api

## Roadmap

Here are some planned features and improvements for the `c3-api` project:

- [ ] **Http 2.0**
- [ ] **Performance Optimizations**
- [ ] **Benchmarks**
- [ ] **Pluggable Template rendering backend**
- [ ] **Testing**: Robust test suite in c3 for unit tests and with python for integration tests.
- [ ] **Documentation**: Improve documentation with detailed examples and usage guides.
- [ ] **Pipeline**: Pipeline to build and test the library, including performance and memory leak tests

## Docker Networking

When running the server in Docker, configure it to listen on `0.0.0.0` inside the container. To make
it accessible only from your local machine, publish the port on the host's loopback interface:

```sh
docker run -p 127.0.0.1:8080:8080 c3api-demo
```

This allows connections from `localhost` on the host while preventing access from other devices on the network.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---
