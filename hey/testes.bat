echo "Testando Traefik..."
hey -n 500 -z 15s http://localhost

echo "Testando cAdvisor..."
hey -n 500 -z 15s http://cadvisor.empresa

echo "Testando Grafana..."
hey -n 500 -z 15s http://grafana.empresa