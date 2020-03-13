from tfc_client import TFCClient

client = TFCClient(token="NCgHy9dppsNDHA.atlasv1.TJmyX37z2RdyfsjTvt9ReqeN67Xp9NDWeAYRmp66279K7yy0dcjX2MiLl8MeZ6RorOE")

org = client.get("organization", id="delta")

response = org.create("workspace", name="test_api_workspace")

print(response)