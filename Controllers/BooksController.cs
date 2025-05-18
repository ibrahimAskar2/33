using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web.Http;
using BooksApiFull.Models;

namespace BooksApiFull.Controllers
{
    public class BooksController : ApiController
    {
        private string connectionString = System.Configuration.ConfigurationManager.ConnectionStrings["DefaultConnection"].ConnectionString;

        [HttpGet]
        [Route("api/books/search")]
        public IHttpActionResult Search(string name)
        {
            var books = new List<Book>();

            using (var conn = new SqlConnection(connectionString))
            {
                conn.Open();
                var cmd = new SqlCommand("SELECT Name, SelPrice, AllQuantity1, Code FROM dbo.MatCard WHERE Name LIKE @name", conn);
                cmd.Parameters.AddWithValue("@name", "%" + name + "%");

                var reader = cmd.ExecuteReader();
                while (reader.Read())
                {
                    books.Add(new Book
                    {
                        Name = reader["Name"].ToString(),
                        SelPrice = reader.GetDecimal(reader.GetOrdinal("SelPrice")),
                        AllQuantity1 = reader.GetDecimal(reader.GetOrdinal("AllQuantity1")),
                        Code = reader["Code"].ToString()
                    });
                }
            }

            return Ok(books);
        }
    }
}
