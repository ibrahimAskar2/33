<%@ Application Language="C#" %>
<script runat="server">
    void Application_Start(object sender, EventArgs e)
    {
        // Code that runs on application startup
        GlobalConfiguration.Configure(WebApiConfig.Register);
    }
</script>
