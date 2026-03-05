                            "Success response should not contain error keys"
                        )
                except ValueError:
                    # Non-JSON is acceptable if it's a redirect or HTML response
                    pass


@pytest.mark.smoke
class TestHealthCheckSmoke:
    """Smoke test for health check endpoint"""

    def test_healthcheck_endpoint(self, plane_server):
        """Test that the health check endpoint is available and responds correctly"""
        # Make a request to the health check endpoint
        response = requests.get(f"{plane_server.url}/")

        # Should be OK
        assert response.status_code == 200, "Health check endpoint should return 200 OK"
