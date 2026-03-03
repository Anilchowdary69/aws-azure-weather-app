const API_KEY = 'b6e4a0fac97758ff47c17209d56753c2';
const API_URL = 'https://api.openweathermap.org/data/2.5/weather';

async function getWeather() {
    const city = document.getElementById('cityInput').value.trim();
    
    if (!city) {
        showError();
        return;
    }

    hideError();
    hideWeatherCard();

    try {
        const response = await fetch(
            `${API_URL}?q=${city}&appid=${API_KEY}&units=imperial`
        );

        if (!response.ok) {
            showError();
            return;
        }

        const data = await response.json();
        displayWeather(data);

    } catch (error) {
        console.error('Error fetching weather:', error);
        showError();
    }
}

function displayWeather(data) {
    document.getElementById('cityName').textContent = 
        `${data.name}, ${data.sys.country}`;
    
    document.getElementById('temperature').textContent = 
        `${Math.round(data.main.temp)}°F`;
    
    document.getElementById('description').textContent = 
        data.weather[0].description;
    
    document.getElementById('humidity').textContent = 
        `${data.main.humidity}%`;
    
    document.getElementById('windSpeed').textContent = 
        `${Math.round(data.wind.speed)} mph`;
    
    document.getElementById('feelsLike').textContent = 
        `${Math.round(data.main.feels_like)}°F`;

    document.getElementById('weatherCard').style.display = 'block';
}

function showError() {
    document.getElementById('errorMsg').style.display = 'block';
    document.getElementById('weatherCard').style.display = 'none';
}

function hideError() {
    document.getElementById('errorMsg').style.display = 'none';
}

function hideWeatherCard() {
    document.getElementById('weatherCard').style.display = 'none';
}

// Allow pressing Enter to search
document.getElementById('cityInput').addEventListener('keypress', function(e) {
    if (e.key === 'Enter') {
        getWeather();
    }
});

// Detect which cloud is serving the app
const hostname = window.location.hostname;
let hostingProvider = 'AWS S3';

if (hostname.includes('web.core.windows.net') || hostname.includes('azure')) {
    hostingProvider = 'Azure Blob Storage';
} else if (hostname.includes('amazonaws.com') || hostname.includes('cloudfront.net')) {
    hostingProvider = 'AWS S3';
} else if (hostname.includes('your-domain.com')) {
    hostingProvider = 'AWS S3'; // or Azure depending on failover
}

document.querySelector('.footer p').innerHTML = 
    `Currently served from <strong>${hostingProvider}</strong>`;