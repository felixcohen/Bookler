window.onload = function ()
{
var opts = {
				lines: 12, // The number of lines to draw
				length: 19, // The length of each line
				width: 9, // The line thickness
				radius: 32, // The radius of the inner circle
				color: '#000', // #rgb or #rrggbb
				speed: 0.7, // Rounds per second
				trail: 75, // Afterglow percentage
				shadow: true // Whether to render a shadow
				};
				var target = document.getElementById('spinner');
				var spinner = new Spinner(opts).spin(target);
			}